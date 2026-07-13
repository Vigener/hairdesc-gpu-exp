#include <mpi.h>
#include <omp.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <vector>




struct Particle {
	double mass;
	double x, y, z;
	double vx, vy, vz;
};

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

  std::vector<Particle> particles(N); // 全ての星の情報を全プロセスで共有するためのベクトル

	if (rank == 0) {
    // 外部ファイルに依存せず、ランダムな初期値を生成してスケーリングに備える
    std::srand(42);
    for (int i = 0; i < N; ++i) {
      particles[i].mass = 1.0 + (std::rand() / (double)RAND_MAX);
      particles[i].x = (std::rand() / (double)RAND_MAX) * 100.0;
      particles[i].y = (std::rand() / (double)RAND_MAX) * 100.0;
      particles[i].z = (std::rand() / (double)RAND_MAX) * 100.0;
      particles[i].vx = 0.0;
      particles[i].vy = 0.0;
      particles[i].vz = 0.0;
    }
	}

  // 全プロセスで初期データを共有する
	MPI_Bcast(particles.data(), N * sizeof(Particle), MPI_BYTE, 0, MPI_COMM_WORLD);

  // 全プロセスが初期データの受け取りを終えるまで待つ
	MPI_Barrier(MPI_COMM_WORLD);

  // 初期状態を保存
  std::vector<Particle> initial_particles = particles;
  std::vector<double> run_times(3);

  // 1回実行してタイミングを計測
  for (int run = 0; run < 1; ++run) {
    // 各実行の初めに初期状態に戻す
    particles = initial_particles;

    // 時間計測開始
    const double start_time = MPI_Wtime();

    // シミュレーションのメインループ
    for (int step = 0; step < STEPS; ++step) {
		  std::vector<Particle> next_particles(particles.begin() + start_index, particles.begin() + end_index);

      #pragma omp parallel for default(none) shared(particles, next_particles, N, start_index, end_index, DT, G, local_particle_count)
      for (int i = start_index; i < end_index; ++i) {
        double ax = 0.0;
        double ay = 0.0;
        double az = 0.0;

        for (int j = 0; j < N; ++j) {
          if (i == j) {
            continue;
          }

          const double dx = particles[j].x - particles[i].x;
          const double dy = particles[j].y - particles[i].y;
          const double dz = particles[j].z - particles[i].z;
          const double dist2 = dx * dx + dy * dy + dz * dz + 1e-10;
          const double dist = std::sqrt(dist2);
          const double f = G * particles[j].mass / dist2;

          ax += f * dx / dist;
          ay += f * dy / dist;
          az += f * dz / dist;
        }

        // 速度と位置の更新
        next_particles[i - start_index].vx = particles[i].vx + DT * ax;
        next_particles[i - start_index].vy = particles[i].vy + DT * ay;
        next_particles[i - start_index].vz = particles[i].vz + DT * az;

        next_particles[i - start_index].x = particles[i].x + DT * next_particles[i - start_index].vx;
        next_particles[i - start_index].y = particles[i].y + DT * next_particles[i - start_index].vy;
        next_particles[i - start_index].z = particles[i].z + DT * next_particles[i - start_index].vz;
      }

      // 結果の集約(Allgatherで行う)
      // MPI_Allgather(送るデータの先頭アドレス, 送るデータのサイズ, データの型, 受け取るデータの先頭アドレス, 受け取るデータのサイズ, データの型, コミュニケータ)
      MPI_Allgather(next_particles.data(), local_particle_count * static_cast<int>(sizeof(Particle)), MPI_BYTE,
                particles.data(), local_particle_count * static_cast<int>(sizeof(Particle)), MPI_BYTE, MPI_COMM_WORLD);
      // これにより、共有されている変数particlesが全てのプロセスで更新される
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
			double x = particles[i].x;
			double y = particles[i].y;
			double z = particles[i].z;
			outx.write(reinterpret_cast<const char*>(&x), sizeof(double));
			outy.write(reinterpret_cast<const char*>(&y), sizeof(double));
			outz.write(reinterpret_cast<const char*>(&z), sizeof(double));
		}
		outx.close();
		outy.close();
		outz.close();
	}

	MPI_Finalize(); // MPIの終了
	return 0;
}
