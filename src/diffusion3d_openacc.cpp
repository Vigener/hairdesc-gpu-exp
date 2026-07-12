#include <mpi.h>
#include <omp.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

void diffusion3d_compute(int rank, int nx, int ny, int nz, int mgn, float dx, float dy, float dz, float dt, float kappa, const float *f, float *fn, int k_start, int k_end, int stream_id) {
    float cc = 1.0f - 2.0f * kappa * dt * (1.0f / (dx * dx) + 1.0f / (dy * dy) + 1.0f / (dz * dz));
    float ce = kappa * dt / (dx * dx);
    float cw = ce;
    float cn = kappa * dt / (dy * dy);
    float cs = cn;
    float ct = kappa * dt / (dz * dz);
    float cb = ct;

    #pragma acc parallel loop independent collapse(3) present(f[0:nx*ny*(nz+2*mgn)], fn[0:nx*ny*(nz+2*mgn)]) async(stream_id)
    for (int k = k_start; k < k_end; ++k) {
        for (int j = 0; j < ny; ++j) {
            for (int i = 0; i < nx; ++i) {
                int ix = nx * ny * (k + mgn) + nx * j + i;
                int ip = (i == nx - 1) ? ix : ix + 1;
                int im = (i == 0)      ? ix : ix - 1;
                int jp = (j == ny - 1) ? ix : ix + nx;
                int jm = (j == 0)      ? ix : ix - nx;
                int kp = ix + nx * ny;
                int km = ix - nx * ny;

                fn[ix] = cc * f[ix] + ce * f[ip] + cw * f[im] +
                         cn * f[jp] + cs * f[jm] + ct * f[kp] + cb * f[km];
            }
        }
    }
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (argc < 2) {
        if (rank == 0) {
            std::fprintf(stderr, "Usage: %s nodes [N]\n", argv[0]);
        }
        MPI_Finalize();
        return 1;
    }

    const int nodes = std::atoi(argv[1]);
    
    // N corresponds to the local grid size per dimension
    int N = 256; 
    if (argc > 2) {
        N = std::atoi(argv[2]);
    }

    const int nx = N;
    const int ny = N;
    const int nz = N;
    const int mgn = 1;
    const int ln = nx * ny * (nz + 2 * mgn);

    const int STEPS = 10;
    const float dx = 0.1f, dy = 0.1f, dz = 0.1f;
    const float dt = 0.001f;
    const float kappa = 1.0f;

    std::vector<float> f_vec(ln, 0.0f);
    std::vector<float> fn_vec(ln, 0.0f);

    if (rank == size / 2) {
        f_vec[nx * ny * (nz / 2 + mgn) + nx * (ny / 2) + nx / 2] = 1000.0f;
    }

    float* f = f_vec.data();
    float* fn = fn_vec.data();

    int rank_up = (rank < size - 1) ? rank + 1 : MPI_PROC_NULL;
    int rank_down = (rank > 0) ? rank - 1 : MPI_PROC_NULL;

    MPI_Barrier(MPI_COMM_WORLD);
    double start_time = MPI_Wtime();

    #pragma acc data copy(f[0:ln]) create(fn[0:ln])
    {
        for (int step = 0; step < STEPS; ++step) {
            const int tag = 0;
            MPI_Request reqs[4];
            int num_reqs = 0;

            // GPU-Aware MPIを用いた袖領域の交換 (非同期)
            #pragma acc host_data use_device(f)
            {
                if (rank_up != MPI_PROC_NULL) {
                    MPI_Isend(&f[nx * ny * nz], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
                    MPI_Irecv(&f[nx * ny * (nz + mgn)], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
                }
                if (rank_down != MPI_PROC_NULL) {
                    MPI_Isend(&f[nx * ny * mgn], nx * ny, MPI_FLOAT, rank_down, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
                    MPI_Irecv(&f[0], nx * ny, MPI_FLOAT, rank_down, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
                }
            }

            // 非同期通信の裏で、内部領域の計算を非同期実行 (stream 1)
            if (nz > 2) {
                diffusion3d_compute(rank, nx, ny, nz, mgn, dx, dy, dz, dt, kappa, f, fn, 1, nz - 1, 1);
            }

            // 通信完了を待機
            if (num_reqs > 0) {
                MPI_Waitall(num_reqs, reqs, MPI_STATUSES_IGNORE);
            }

            // 通信完了後、境界領域の計算を非同期実行 (stream 2)
            // k = 0
            diffusion3d_compute(rank, nx, ny, nz, mgn, dx, dy, dz, dt, kappa, f, fn, 0, 1, 2);
            // k = nz - 1
            if (nz > 1) {
                diffusion3d_compute(rank, nx, ny, nz, mgn, dx, dy, dz, dt, kappa, f, fn, nz - 1, nz, 2);
            }

            // すべてのストリームの計算完了を待機
            #pragma acc wait

            // ポインタの入れ替え。実際のデータ転送は起きずGPU上での参照先を切り替える。
            std::swap(f, fn);
        }
    }

    MPI_Barrier(MPI_COMM_WORLD);
    double end_time = MPI_Wtime();
    double avg_time = end_time - start_time;

    if (rank == 0) {
        int omp_threads = omp_get_max_threads();
        std::printf("%d,%d,%d,%d,%.6f\n", nodes, size, omp_threads, N, avg_time);
    }

    MPI_Finalize();
    return 0;
}
