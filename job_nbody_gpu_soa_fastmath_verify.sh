#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# コンパイル (Makefile.miyabiのCFLAGS_GPUにfastmathが適用される)
make -f Makefile.miyabi build_cpu_fast build_gpu_soa

# GPU用のラッパースクリプト作成
cat << 'WRAPPER' > wrapper_verify.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
WRAPPER
chmod +x wrapper_verify.sh

# 1. 基準となる CPU AoS 版を実行 (N=64, STEPS=10)
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores
NODES=$(cat ${PBS_NODEFILE} | wc -l)

echo "=== Running Baseline CPU AoS (N=64) ==="
mpiexec -n ${NODES} --map-by ppr:1:node ./bin/nbody_cpu_fast 64 ${NODES} 10
mv output_x.double output_x_aos.double
mv output_y.double output_y_aos.double
mv output_z.double output_z_aos.double

# 2. 検証対象の GPU SoA Fast Math 版を実行 (N=64, STEPS=10)
echo "=== Running GPU SoA Fast Math (N=64) ==="
mpiexec -n ${NODES} --map-by ppr:1:node ./wrapper_verify.sh ./bin/nbody_gpu_soa 64 ${NODES} 10
mv output_x.double output_x_soa.double
mv output_y.double output_y_soa.double
mv output_z.double output_z_soa.double

# 3. 許容誤差での比較実行
echo "=== Verifying Numerical Accuracy (Tolerance: 1e-10) ==="
if python3 verify_tolerant.py; then
    echo "Verification SUCCESS: GPU SoA Fast Math outputs match baseline within tolerance."
else
    echo "Verification FAILED: GPU SoA Fast Math outputs diverge beyond tolerance."
    exit 1
fi

rm -f wrapper_verify.sh
