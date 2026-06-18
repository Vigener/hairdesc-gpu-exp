#include <mpi.h>
#include <omp.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <vector>

// ../file_util/read_double_file.hppから、ファイルからdoubleの配列を読み込む関数をインクルード
#include "../file_util/read_double_file.hpp"


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
  if (argc < 10) {
    if (rank == 0) {
      std::fprintf(stderr, "Usage: %s N nodes m_path x_path y_path z_path vx_path vy_path vz_path\n", argv[0]);
    }
    MPI_Finalize();
    return 1;
  }

  // コマンドライン引数があればNとして読み込み、無ければデフォルト10000にする
	int N = 10000;
	if (argc > 1) {
		N = std::atoi(argv[1]);
	}

  // コマンドライン引数からファイルパスを読み込む
  // nodesは二番目の引数
  const int nodes = std::atoi(argv[2]);
  
  const char* m_path = argv[3]; 
  const char* x_path = argv[4]; 
  const char* y_path = argv[5]; 
  const char* z_path = argv[6];
  const char* vx_path = argv[7];
  const char* vy_path = argv[8];
  const char* vz_path = argv[9];


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
  std::vector<double> masses = read_double_file(m_path, static_cast<std::size_t>(N));
  std::vector<double> xs = read_double_file(x_path, static_cast<std::size_t>(N));
  std::vector<double> ys = read_double_file(y_path, static_cast<std::size_t>(N));
  std::vector<double> zs = read_double_file(z_path, static_cast<std::size_t>(N));
  std::vector<double> vxs = read_double_file(vx_path, static_cast<std::size_t>(N));
  std::vector<double> vys = read_double_file(vy_path, static_cast<std::size_t>(N));
  std::vector<double> vzs = read_double_file(vz_path, static_cast<std::size_t>(N));

    // 読み込んだサイズがNと一致するか確認
    if (masses.size() != static_cast<std::size_t>(N) ||
        xs.size() != static_cast<std::size_t>(N) ||
        ys.size() != static_cast<std::size_t>(N) ||
        zs.size() != static_cast<std::size_t>(N) ||
        vxs.size() != static_cast<std::size_t>(N) ||
        vys.size() != static_cast<std::size_t>(N) ||
        vzs.size() != static_cast<std::size_t>(N)) {
      std::fprintf(stderr, "file size does not match N: %s\n", m_path);
      MPI_Finalize();
      return 1;
    }

    // 読み込んだデータをparticlesにコピー
    for (int i = 0; i < N; ++i) {
      particles[i].mass = masses[i];
      particles[i].x = xs[i];
      particles[i].y = ys[i];
      particles[i].z = zs[i];
      particles[i].vx = vxs[i];
      particles[i].vy = vys[i];
      particles[i].vz = vzs[i];
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
