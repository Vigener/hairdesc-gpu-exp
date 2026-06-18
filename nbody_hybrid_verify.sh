#!/bin/bash
set -euo pipefail

#SBATCH -J nbody_hybrid_verify
#SBATCH -N 4
#SBATCH -p ppx2
#SBATCH -w ppx2-[00-03]
#SBATCH --ntasks=112
#SBATCH -o out/nbody_hybrid_verify_%j.out

# module load openmpi

if command -v module >/dev/null 2>&1; then
    if ! module load openmpi >/dev/null 2>&1; then
        module reset
        module load openmpi
    fi
fi

export OMP_PROC_BIND=${OMP_PROC_BIND:-close}
export OMP_PLACES=${OMP_PLACES:-cores}

default_run_particles=896
default_source_particles=1000

mpi_run() {
    local nodes=$1
    local procs_per_node=$2
    local omp_threads=$3
    shift 3

    export OMP_NUM_THREADS=${omp_threads}
    local mpi_procs=$((nodes * procs_per_node))

    if [[ ${procs_per_node} -eq 1 && ${omp_threads} -ge 27 ]]; then
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            -x OMP_PROC_BIND \
            -x OMP_PLACES \
            --map-by ppr:${procs_per_node}:node \
            --bind-to none \
            "$@"
    else
        mpirun -n ${mpi_procs} \
            ${NQSII_MPIOPTS:-} \
            -x OMP_NUM_THREADS \
            -x OMP_PROC_BIND \
            -x OMP_PLACES \
            --map-by ppr:${procs_per_node}:node:PE=${omp_threads} \
            --bind-to core \
            "$@"
    fi
}

run_case() {
    local label=$1
    local nodes=$2
    local procs_per_node=$3
    local omp_threads=$4
    local run_particles=${5:-${default_run_particles}}
    local source_particles=${6:-${default_source_particles}}
    local data_dir="./grav_data/n${source_particles}"

    echo
    echo "=== ${label} ==="
    echo "nodes=${nodes}, mpi_per_node=${procs_per_node}, omp_threads=${omp_threads}, N=${run_particles}"

    echo "--- binding probe: show_num_of_core ---"
    mpi_run "${nodes}" "${procs_per_node}" "${omp_threads}" \
        --report-bindings \
        ./show_num_of_core

    echo "--- benchmark: nbody_hybrid ---"
    mpi_run "${nodes}" "${procs_per_node}" "${omp_threads}" \
        --report-bindings \
        ./nbody_hybrid \
        "${run_particles}" \
        "${nodes}" \
        "${data_dir}/m.double" \
        "${data_dir}/x.double" \
        "${data_dir}/y.double" \
        "${data_dir}/z.double" \
        "${data_dir}/vx.double" \
        "${data_dir}/vy.double" \
        "${data_dir}/vz.double"
}

usage() {
    cat <<'EOF'
Usage:
  sbatch nbody_hybrid_verify.sh [case]
  bash   nbody_hybrid_verify.sh [case]

Cases:
  all        Run all verification cases below.
  1n-1p-28t  1 node, 1 MPI rank/node, 28 OpenMP threads.
  1n-4p-7t   1 node, 4 MPI ranks/node, 7 OpenMP threads.
  1n-2p-14t  1 node, 2 MPI ranks/node, 14 OpenMP threads.
  1n-1p-27t  1 node, 1 MPI rank/node, 27 OpenMP threads.
  2n-1p-28t  2 nodes, 1 MPI rank/node, 28 OpenMP threads.
  2n-2p-14t  2 nodes, 2 MPI ranks/node, 14 OpenMP threads.
  4n-1p-28t  4 nodes, 1 MPI rank/node, 28 OpenMP threads.
  4n-1p-27t  4 nodes, 1 MPI rank/node, 27 OpenMP threads.
EOF
}

echo "Running a single verification case"
run_case "1 node / 1 rank / 28 threads" 1 1 28
