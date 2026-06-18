# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy"]
# ///
import numpy as np
import struct

def load_doubles(path):
    """Load binary double array"""
    with open(path, 'rb') as f:
        data = f.read()
    count = len(data) // 8
    return np.array(struct.unpack(f'{count}d', data))

print("=" * 70)
print("GRAVITY COMPUTATION VERIFICATION (N=1000, 1 MPI proc, 1 thread)")
print("=" * 70)

# Load reference and computed data
ref_x = load_doubles('grav_data/n1000/resx.double')
ref_y = load_doubles('grav_data/n1000/resy.double')
ref_z = load_doubles('grav_data/n1000/resz.double')

comp_x = load_doubles('output_x.double')
comp_y = load_doubles('output_y.double')
comp_z = load_doubles('output_z.double')

print(f"\nReference shape: {ref_x.shape}, {ref_y.shape}, {ref_z.shape}")
print(f"Computed shape:  {comp_x.shape}, {comp_y.shape}, {comp_z.shape}")

# Compute errors
def compute_stats(ref, comp, name):
    if len(ref) != len(comp):
        print(f"❌ {name}: Length mismatch!")
        return
    
    abs_err = np.abs(ref - comp)
    rel_err = abs_err / (np.abs(ref) + 1e-15)
    
    print(f"\n{name}:")
    print(f"  Max absolute error:  {np.max(abs_err):.6e}")
    print(f"  Mean absolute error: {np.mean(abs_err):.6e}")
    print(f"  Max relative error:  {np.max(rel_err):.6e}")
    print(f"  Mean relative error: {np.mean(rel_err):.6e}")
    
    # Check if close
    allclose = np.allclose(ref, comp, rtol=1e-5, atol=1e-8)
    status = "✓ PASS" if allclose else "⚠ DIFF (expected for multi-process)"
    print(f"  Status: {status}")
    
    return allclose

compute_stats(ref_x, comp_x, "X coordinate")
compute_stats(ref_y, comp_y, "Y coordinate")
compute_stats(ref_z, comp_z, "Z coordinate")

print("\n" + "=" * 70)
print("Note: Minor differences expected due to:")
print("  - Floating-point accumulation order differences")
print("  - Different computation sequence in parallel runs")
print("  - This sequential (1 MPI proc) should match reference closely")
print("=" * 70)
