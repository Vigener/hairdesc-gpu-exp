#include <mpi.h>
#include <omp.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <vector>

// SoA (Structure of Arrays) 版 N-body (OpenACC)
// AoS (struct Particle の配列) を廃止し、成分ごとの独立した連続配列で保持することで、
// GPU 上の非合体メモリアクセスを解消し Coalesced Access を実現する。

int main(int argc, char** argv) {
	MPI_Init(&argc, &argv); // MPIの初期化

  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank); // 自分のランク（プロセスID）を取得
  MPI_Comm_size(MPI_COMM_WORLD, &size); // 全プロセスの数を取得

  // 引数が足りない場合はエラーを出して終了
  if (argc < 4) {
    if (rank == 0) {
      std::fprintf(stderr, "Usage: %s N nodes steps\n", argv[0]);
    }
    MPI_Finalize();
    return 1;
  }

  int N = std::atoi(argv[1]);
  const int nodes = std::atoi(argv[2]);
  const int STEPS = std::atoi(argv[3]); // ステップ数（引数で指定）


	const double DT = 1.0; // タイムステップ
	const double G = 1.0; // 万有引力定数


	const int omp_threads = omp_get_max_threads();

  
  // 各プロセスの担当する星の数を計算
	const int local_particle_count = N / size; // 割り切れることにする
  if (N % size != 0) {
    if (rank == 0) {
      std::fprintf(stderr, "N must be divisible by MPI process count: N=%d, size=%d\n", N, size);
    }
    MPI_Finalize();
    return 1;
  }
	const int start_index = rank * local_particle_count;
	const int end_index = start_index + local_particle_count;

  // SoA: 各成分を独立した double 配列としてヒープから確保（全粒子分・全プロセス共有）
  double* mass = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* x    = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* y    = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* z    = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vx   = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vy   = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vz   = static_cast<double*>(std::malloc(sizeof(double) * N));

  // 更新先（ローカル担当分）
  double* nx  = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));
  double* ny  = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));
  double* nz  = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));
  double* nvx = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));
  double* nvy = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));
  double* nvz = static_cast<double*>(std::malloc(sizeof(double) * local_particle_count));

  // 初期状態の保存用
  double* x0  = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* y0  = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* z0  = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vx0 = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vy0 = static_cast<double*>(std::malloc(sizeof(double) * N));
  double* vz0 = static_cast<double*>(std::malloc(sizeof(double) * N));

	if (rank == 0) {
    // 外部ファイルに依存せず、ランダムな初期値を生成してスケーリングに備える
    std::srand(42);
    for (int i = 0; i < N; ++i) {
      mass[i] = 1.0 + (std::rand() / (double)RAND_MAX);
      x[i] = (std::rand() / (double)RAND_MAX) * 100.0;
      y[i] = (std::rand() / (double)RAND_MAX) * 100.0;
      z[i] = (std::rand() / (double)RAND_MAX) * 100.0;
    }
	}
  // 初期速度は全プロセスで 0.0（決定的な初期条件のため Bcast 不要）
  for (int i = 0; i < N; ++i) {
    vx[i] = 0.0;
    vy[i] = 0.0;
    vz[i] = 0.0;
  }

  // 全プロセスで初期データを共有する
	MPI_Bcast(x, N, MPI_DOUBLE, 0, MPI_COMM_WORLD);
	MPI_Bcast(y, N, MPI_DOUBLE, 0, MPI_COMM_WORLD);
	MPI_Bcast(z, N, MPI_DOUBLE, 0, MPI_COMM_WORLD);
	MPI_Bcast(mass, N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

  // 全プロセスが初期データの受け取りを終えるまで待つ
	MPI_Barrier(MPI_COMM_WORLD);

  // 初期状態を保存
  std::memcpy(x0, x, sizeof(double) * N);
  std::memcpy(y0, y, sizeof(double) * N);
  std::memcpy(z0, z, sizeof(double) * N);
  std::memcpy(vx0, vx, sizeof(double) * N);
  std::memcpy(vy0, vy, sizeof(double) * N);
  std::memcpy(vz0, vz, sizeof(double) * N);

  std::vector<double> run_times(3);

  // 1回実行してタイミングを計測
  for (int run = 0; run < 1; ++run) {
    // 各実行の初めに初期状態に戻す
    std::memcpy(x, x0, sizeof(double) * N);
    std::memcpy(y, y0, sizeof(double) * N);
    std::memcpy(z, z0, sizeof(double) * N);
    std::memcpy(vx, vx0, sizeof(double) * N);
    std::memcpy(vy, vy0, sizeof(double) * N);
    std::memcpy(vz, vz0, sizeof(double) * N);

    // 時間計測開始
    const double start_time = MPI_Wtime();

    #pragma acc data copy(x[0:N], y[0:N], z[0:N], mass[0:N]) \
                       create(vx[0:N], vy[0:N], vz[0:N]) \
                       create(nx[0:local_particle_count], ny[0:local_particle_count], nz[0:local_particle_count]) \
                       create(nvx[0:local_particle_count], nvy[0:local_particle_count], nvz[0:local_particle_count])
    {
      // 速度は create 割り当てのため、デバイス側で初期化する（初期条件は全て 0.0）
      #pragma acc parallel loop
      for (int i = 0; i < N; ++i) {
        vx[i] = 0.0;
        vy[i] = 0.0;
        vz[i] = 0.0;
      }

      // シミュレーションのメインループ
      for (int step = 0; step < STEPS; ++step) {
        #pragma acc parallel loop independent
        for (int i = start_index; i < end_index; ++i) {
          double ax = 0.0;
          double ay = 0.0;
          double az = 0.0;

          // 自粒子のデータはレジスタに保持（x[i] は連続スレッドが連続アクセス＝合体）
          const double xi = x[i];
          const double yi = y[i];
          const double zi = z[i];

          for (int j = 0; j < N; ++j) {
            if (i == j) {
              continue;
            }

            // SoA により x[j] 等は成分ごとの連続領域からフェッチされる（Coalesced Access）
            const double dx = x[j] - xi;
            const double dy = y[j] - yi;
            const double dz = z[j] - zi;
            const double dist2 = dx * dx + dy * dy + dz * dz + 1e-10;
            
            // 1.0 / sqrt を明示的に作り、コンパイラに rsqrt 命令を強制する
            const double inv_dist = 1.0 / std::sqrt(dist2);
            const double inv_dist3 = inv_dist * inv_dist * inv_dist;
            
            // 割り算を完全に消滅させ、すべて「掛け算（1サイクル）」にする
            const double f = G * mass[j] * inv_dist3;

            ax += f * dx;
            ay += f * dy;
            az += f * dz;

          }

          // 速度と位置の更新
          const int li = i - start_index;
          nvx[li] = vx[i] + DT * ax;
          nvy[li] = vy[i] + DT * ay;
          nvz[li] = vz[i] + DT * az;

          nx[li] = x[i] + DT * nvx[li];
          ny[li] = y[i] + DT * nvy[li];
          nz[li] = z[i] + DT * nvz[li];
        }

        // 結果の集約(Allgatherで行う): 成分配列ごとに集約する
        #pragma acc host_data use_device(nx, ny, nz, nvx, nvy, nvz, x, y, z, vx, vy, vz)
        {
          MPI_Allgather(nx, local_particle_count, MPI_DOUBLE,
                        x, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
          MPI_Allgather(ny, local_particle_count, MPI_DOUBLE,
                        y, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
          MPI_Allgather(nz, local_particle_count, MPI_DOUBLE,
                        z, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
          MPI_Allgather(nvx, local_particle_count, MPI_DOUBLE,
                        vx, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
          MPI_Allgather(nvy, local_particle_count, MPI_DOUBLE,
                        vy, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
          MPI_Allgather(nvz, local_particle_count, MPI_DOUBLE,
                        vz, local_particle_count, MPI_DOUBLE, MPI_COMM_WORLD);
        }
      }
    }

	  MPI_Barrier(MPI_COMM_WORLD); // 全プロセスが計算を終えるまで待つ

    // 時間計測終了
    const double end_time = MPI_Wtime();
    run_times[run] = end_time - start_time;
  }

  // 平均時間を計算
  double total_time = 0.0;
  for (int i = 0; i < 1; ++i) {
    total_time += run_times[i];
  }
  double avg_time = total_time / 1.0;

  // FLOPS計算: 1粒子ペアあたり20FLOP（差分3+dist2計算5+sqrt1+f計算2+加速度更新9）
  // N*(N-1)ペア × STEPSステップ
  const double total_flop = 20.0 * (double)N * (double)(N - 1) * (double)STEPS;
  const double gflops = (rank == 0) ? (total_flop / avg_time / 1.0e9) : 0.0;

  // 結果の出力
	if (rank == 0) {
		// CSV形式の計時結果: nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS
		std::printf("%d,%d,%d,%d,%d,%.6f,%.3f\n", nodes, size, omp_threads, N, STEPS,
						avg_time, gflops);
		std::ofstream outx("output_x.double", std::ios::binary);
		std::ofstream outy("output_y.double", std::ios::binary);
		std::ofstream outz("output_z.double", std::ios::binary);
		
		for (int i = 0; i < N; ++i) {
			outx.write(reinterpret_cast<const char*>(&x[i]), sizeof(double));
			outy.write(reinterpret_cast<const char*>(&y[i]), sizeof(double));
			outz.write(reinterpret_cast<const char*>(&z[i]), sizeof(double));
		}
		outx.close();
		outy.close();
		outz.close();
	}

  // ヒープメモリの解放
  std::free(mass);
  std::free(x);
  std::free(y);
  std::free(z);
  std::free(vx);
  std::free(vy);
  std::free(vz);
  std::free(nx);
  std::free(ny);
  std::free(nz);
  std::free(nvx);
  std::free(nvy);
  std::free(nvz);
  std::free(x0);
  std::free(y0);
  std::free(z0);
  std::free(vx0);
  std::free(vy0);
  std::free(vz0);

	MPI_Finalize(); // MPIの終了
	return 0;
}
