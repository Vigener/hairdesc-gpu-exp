#!/bin/bash
#set -euo pipefail

# Optional Slurm directives (uncomment for sbatch submission)
#SBATCH -J show_num_of_core
#SBATCH -N 4
#SBATCH -p ppx2
#SBATCH -w ppx2-[00-03]
#SBATCH --ntasks=112
#SBATCH -o out/show_num_of_core_%j.out

module load openmpi

echo "=========================================="
echo "show_num_of_core.sh - Thread Binding Verification"
echo "=========================================="

# 実行用のヘルパー関数を定義（引数: ノード数, MPI/ノード, OMP_スレッド数）
run_exp() {
    local nodes=$1
    local procs_per_node=$2
    local omp_threads=$3
    local source_particles=${4:-1000}
    local data_dir="./grav_data/n${source_particles}"

    export OMP_NUM_THREADS=${omp_threads}
    export OMP_PROC_BIND=${OMP_PROC_BIND:-close}
    export OMP_PLACES=${OMP_PLACES:-cores}
    
    local mpi_procs=$((nodes * procs_per_node))

    echo
    echo "Configuration: ${nodes}n-${procs_per_node}p-${omp_threads}t"
    echo "  Total MPI processes: ${mpi_procs}"
    echo "  Threads per process: ${omp_threads}"
    echo "  Expected output lines: $((mpi_procs * omp_threads))"
    echo
    echo "--- MPI Rank Binding (--report-bindings) ---"

    # 1 rank/node かつ多数スレッド時は、ソケット跨ぎの core bind エラーを回避する。
    if [[ ${procs_per_node} -eq 1 && ${omp_threads} -ge 27 ]]; then
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            --map-by ppr:${procs_per_node}:node \
            --bind-to none \
            --report-bindings \
            ./show_num_of_core
    else
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            --map-by ppr:${procs_per_node}:node:PE=${omp_threads} \
            --bind-to core \
            --report-bindings \
            ./show_num_of_core
    fi
}

# Examples: uncomment desired configurations
# Single-node configurations
run_exp 1 1 28   # 1n-1p-28t: 1 MPI process, 28 threads (uses --bind-to none)
run_exp 1 2 14   # 1n-2p-14t: 2 MPI processes, 14 threads each (uses PE=14)
run_exp 1 4 7    # 1n-4p-7t: 4 MPI processes, 7 threads each (uses PE=7)
run_exp 1 28 1   # 1n-28p-1t: 28 MPI processes, 1 thread each
# run_exp 1 1 27   # 1n-1p-27t: 1 MPI process, 27 threads (OS Jitter mitigation)

# Multi-node configurations
run_exp 2 1 28   # 2n-1p-28t: 1 process per 2 nodes, 28 threads each
run_exp 2 2 14   # 2n-2p-14t: 2 processes per 2 nodes, 14 threads each
run_exp 2 4 7    # 2n-4p-7t: 4 processes per 2 nodes, 7 threads each (uses PE=7)
run_exp 2 28 1   # 2n-28p-1t: 28 processes per 2 nodes, 1 thread each
run_exp 4 1 28   # 4n-1p-28t: 1 process per 4 nodes, 28 threads each
run_exp 4 2 14   # 4n-2p-14t: 2 processes per 4 nodes, 14 threads each
run_exp 4 4 7    # 4n-4p-7t: 4 processes per 4 nodes, 7 threads each (uses PE=7)
run_exp 4 28 1   # 4n-28p-1t: 28 processes per 4 nodes, 1 thread each
# run_exp 4 1 27   # 4n-1p-27t: 1 process per 4 nodes, 27 threads each

# Default: run single-node all-core configuration
# run_exp 1 28 1 1000

echo
echo "=========================================="
echo "Completion"
echo "=========================================="
