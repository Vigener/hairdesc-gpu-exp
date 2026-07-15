#include <mpi.h>
#include <omp.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

void diffusion3d(int rank, int nx, int ny, int nz, int mgn, float dx, float dy, float dz, float dt, float kappa, const float *f, float *fn) {
    float cc = 1.0f - 2.0f * kappa * dt * (1.0f / (dx * dx) + 1.0f / (dy * dy) + 1.0f / (dz * dz));
    float ce = kappa * dt / (dx * dx);
    float cw = ce;
    float cn = kappa * dt / (dy * dy);
    float cs = cn;
    float ct = kappa * dt / (dz * dz);
    float cb = ct;

    #pragma omp parallel for collapse(3)
    for (int k = 0; k < nz; ++k) {
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

    if (argc < 4) {
        if (rank == 0) {
            std::fprintf(stderr, "Usage: %s nodes N steps\n", argv[0]);
        }
        MPI_Finalize();
        return 1;
    }

    const int nodes = std::atoi(argv[1]);
    const int N = std::atoi(argv[2]);
    const int STEPS = std::atoi(argv[3]);

    const int nx = N;
    const int ny = N;
    const int nz = N;
    const int mgn = 1;
    const int ln = nx * ny * (nz + 2 * mgn);

    const float dx = 0.1f, dy = 0.1f, dz = 0.1f;
    const float dt = 0.001f;
    const float kappa = 1.0f;

    std::vector<float> f(ln, 0.0f);
    std::vector<float> fn(ln, 0.0f);

    // 初期化 (中心に熱源)
    if (rank == size / 2) {
        f[nx * ny * (nz / 2 + mgn) + nx * (ny / 2) + nx / 2] = 1000.0f;
    }

    int rank_up = (rank < size - 1) ? rank + 1 : MPI_PROC_NULL;
    int rank_down = (rank > 0) ? rank - 1 : MPI_PROC_NULL;

    MPI_Barrier(MPI_COMM_WORLD);
    double start_time = MPI_Wtime();

    for (int step = 0; step < STEPS; ++step) {
        const int tag = 0;
        MPI_Status status;

        // 袖領域の交換
        MPI_Send(&f[nx * ny * nz], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD);
        MPI_Recv(&f[0], nx * ny, MPI_FLOAT, rank_down, tag, MPI_COMM_WORLD, &status);

        MPI_Send(&f[nx * ny * mgn], nx * ny, MPI_FLOAT, rank_down, tag, MPI_COMM_WORLD);
        MPI_Recv(&f[nx * ny * (nz + mgn)], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD, &status);

        diffusion3d(rank, nx, ny, nz, mgn, dx, dy, dz, dt, kappa, f.data(), fn.data());

        std::swap(f, fn);
    }

    MPI_Barrier(MPI_COMM_WORLD);
    double end_time = MPI_Wtime();
    double avg_time = end_time - start_time;

    if (rank == 0) {
        int omp_threads = omp_get_max_threads();
        // 演算量: NX*NY*NZ * (7乗算 + 6加算 = 13 FLOP) × STEPS
        const double total_flop = 13.0 * nx * ny * nz * STEPS;
        // メモリ読み書き量: NX*NY*NZ * (7 float読み込み + 1 float書き込み = 8 floats) × 4 bytes × STEPS
        const double total_bytes = 8.0 * 4.0 * nx * ny * nz * STEPS;
        const double gflops = total_flop / avg_time / 1e9;
        const double bandwidth_gbs = total_bytes / avg_time / 1e9;
        // nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)
        std::printf("%d,%d,%d,%d,%d,%.6f,%.3f,%.3f\n", 
                    nodes, size, omp_threads, N, STEPS, avg_time, gflops, bandwidth_gbs);
    }

    MPI_Finalize();
    return 0;
}
