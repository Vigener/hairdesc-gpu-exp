.PHONY: build run clean prepare build_acc run_acc

# デフォルトターゲット
all: build build_acc

# ディレクトリ準備
prepare:
	mkdir -p out bin

# 既存: MPI+OpenMPのハイブリッドコンパイル
build: prepare
	module load openmpi && \
	mpicxx -O3 -Wall -fopenmp src/nbody_hybrid.cpp -o bin/nbody_hybrid

# 新規: OpenACCによるGPUコンパイル (PPX環境でのnvhpc等を想定)
build_acc: prepare
	module load nvhpc || true ; \
	nvc++ -acc -gpu=managed -Minfo=accel -O3 src/nbody_openacc.cpp -o bin/nbody_openacc

# 既存: ハイブリッド版実行（Slurmジョブとして投入）
run: build
	sbatch nbody_hybrid.sh

# 新規: OpenACC版実行（Slurmジョブとして投入）
run_acc: build_acc
	sbatch job_ppx_openacc.sh

# ローカル実行テスト用（小規模）
test: build prepare
	# テスト用の簡易実行（実装例）
	echo "Test compilation successful"

# クリーンアップ
clean:
	rm -f bin/nbody_hybrid bin/nbody_openacc
	rm -rf out/

# 詳細表示
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make build      - Compile hybrid code (src/nbody_hybrid.cpp)"
	@echo "  make build_acc  - Compile OpenACC code (src/nbody_openacc.cpp)"
	@echo "  make run        - Compile and submit hybrid job"
	@echo "  make run_acc    - Compile and submit OpenACC job"
	@echo "  make test       - Compile and verify build"
	@echo "  make clean      - Remove compiled binaries and output directory"
