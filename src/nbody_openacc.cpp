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
  if (argc < 3) {
    if (rank == 0) {
      std::fprintf(stderr, "Usage: %s N nodes\n", argv[0]);
    }
    MPI_Finalize();
    return 1;
  }

  int N = std::atoi(argv[1]);
  const int nodes = std::atoi(argv[2]);


	const int STEPS = 1000; // ステップ数
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

  // 3回実行してタイミングを計測
  for (int run = 0; run < 3; ++run) {
    // 各実行の初めに初期状態に戻す
    particles = initial_particles;

    std::vector<Particle> next_particles(local_particle_count);
    Particle* p_data = particles.data();
    Particle* np_data = next_particles.data();

    // 時間計測開始
    const double start_time = MPI_Wtime();

    #pragma acc data copy(p_data[0:N]) create(np_data[0:local_particle_count])
    {
      // シミュレーションのメインループ
      for (int step = 0; step < STEPS; ++step) {
        #pragma acc parallel loop independent
        for (int i = start_index; i < end_index; ++i) {
          double ax = 0.0;
          double ay = 0.0;
          double az = 0.0;

          for (int j = 0; j < N; ++j) {
            if (i == j) {
              continue;
            }

            const double dx = p_data[j].x - p_data[i].x;
            const double dy = p_data[j].y - p_data[i].y;
            const double dz = p_data[j].z - p_data[i].z;
            const double dist2 = dx * dx + dy * dy + dz * dz + 1e-10;
            const double dist = std::sqrt(dist2);
            const double f = G * p_data[j].mass / dist2;

            ax += f * dx / dist;
            ay += f * dy / dist;
            az += f * dz / dist;
          }

          // 速度と位置の更新
          np_data[i - start_index].vx = p_data[i].vx + DT * ax;
          np_data[i - start_index].vy = p_data[i].vy + DT * ay;
          np_data[i - start_index].vz = p_data[i].vz + DT * az;

          np_data[i - start_index].x = p_data[i].x + DT * np_data[i - start_index].vx;
          np_data[i - start_index].y = p_data[i].y + DT * np_data[i - start_index].vy;
          np_data[i - start_index].z = p_data[i].z + DT * np_data[i - start_index].vz;
        }

        // 結果の集約(Allgatherで行う)
        #pragma acc host_data use_device(np_data, p_data)
        {
          MPI_Allgather(np_data, local_particle_count * static_cast<int>(sizeof(Particle)), MPI_BYTE,
                        p_data, local_particle_count * static_cast<int>(sizeof(Particle)), MPI_BYTE, MPI_COMM_WORLD);
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
  for (int i = 0; i < 3; ++i) {
    total_time += run_times[i];
  }
  double avg_time = total_time / 3.0;

  // 結果の出力
	if (rank == 0) {
		// CSV形式の計時結果（平均値）
		std::printf("%d,%d,%d,%d,%.6f\n", nodes, size, omp_threads, N,
						avg_time);
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
