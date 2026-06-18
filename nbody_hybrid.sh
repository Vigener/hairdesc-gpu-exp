#!/bin/bash
#set -euo pipefail

#SBATCH -J nbody_hybrid
#SBATCH -N 4
#SBATCH -p ppx2
#SBATCH -w ppx2-[00-03]
#SBATCH --ntasks=112     # 全ノードの合計コア数（スロット）を最大112として確保
#SBATCH -o out/nbody_hybrid_%j.out

module load openmpi


echo "Nodes,MPI_Processes,OpenMP_Threads,NumParticles,Time_sec"

# 実行用のヘルパー関数を定義（引数: ノード数, MPIプロセス数, OMPスレッド数）
run_exp() {
    local nodes=$1
    # --map-by ppr:X:node:PE=N は 1ノードあたりXプロセス、1プロセスあたりNコアを割当
    local procs_per_node=$2
    local omp_threads=$3
    local run_particles=$4
    local source_particles=$5
    local data_dir="./grav_data/n${source_particles}"

    export OMP_NUM_THREADS=${omp_threads}
    export OMP_PROC_BIND=${OMP_PROC_BIND:-close}
    export OMP_PLACES=${OMP_PLACES:-cores}
    # -n は全体のMPIプロセス数
    local mpi_procs=$((nodes * procs_per_node))  # 全体のMPIプロセス数

    # 1 rank/node かつ多数スレッド時は、ソケット跨ぎの core bind エラーを回避する。
    if [[ ${procs_per_node} -eq 1 && ${omp_threads} -ge 27 ]]; then
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            -x OMP_PROC_BIND \
            -x OMP_PLACES \
            --map-by ppr:${procs_per_node}:node \
            --bind-to none \
            --report-bindings \
            ./nbody_hybrid \
            ${run_particles} \
            ${nodes} \
            ${data_dir}/m.double \
            ${data_dir}/x.double \
            ${data_dir}/y.double \
            ${data_dir}/z.double \
            ${data_dir}/vx.double \
            ${data_dir}/vy.double \
            ${data_dir}/vz.double
    else
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            -x OMP_PROC_BIND \
            -x OMP_PLACES \
            --map-by ppr:${procs_per_node}:node:PE=${omp_threads} \
            --bind-to core \
            --report-bindings \
            ./nbody_hybrid \
            ${run_particles} \
            ${nodes} \
            ${data_dir}/m.double \
            ${data_dir}/x.double \
            ${data_dir}/y.double \
            ${data_dir}/z.double \
            ${data_dir}/vx.double \
            ${data_dir}/vy.double \
            ${data_dir}/vz.double
    fi
}

# run_exp 1 28 1 896 1000

run_particles_list=(896 2688 8960 26880)
source_particles_list=(1000 3072 10000 30720)
# run_particles_list=(896)
# source_particles_list=(1000)

for idx in "${!run_particles_list[@]}"; do
    run_particles=${run_particles_list[$idx]}
    source_particles=${source_particles_list[$idx]}

    # １ノード
    run_exp 1 28 1 "${run_particles}" "${source_particles}"
    run_exp 1 4 7 "${run_particles}" "${source_particles}"
    # run_exp 1 2 14 "${run_particles}" "${source_particles}"
    run_exp 1 1 28 "${run_particles}" "${source_particles}"

    # ２ノード
    run_exp 2 28 1 "${run_particles}" "${source_particles}"
    run_exp 2 4 7 "${run_particles}" "${source_particles}"
    # run_exp 2 2 14 "${run_particles}" "${source_particles}"
    run_exp 2 1 28 "${run_particles}" "${source_particles}"

    # ４ノード
    run_exp 4 28 1 "${run_particles}" "${source_particles}"
    run_exp 4 4 7 "${run_particles}" "${source_particles}"
    # run_exp 4 2 14 "${run_particles}" "${source_particles}"
    run_exp 4 1 28 "${run_particles}" "${source_particles}"

    # # 28コア全開 vs 27コア (OS Jitter回避)
    # run_exp 1 1 27 "${run_particles}" "${source_particles}"
    # run_exp 2 1 27 "${run_particles}" "${source_particles}"
    # run_exp 4 1 27 "${run_particles}" "${source_particles}"
done