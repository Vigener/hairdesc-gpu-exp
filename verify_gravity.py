# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy"]
# ///
import struct
import sys

def load_doubles(path):
    """Load binary double array"""
    with open(path, 'rb') as f:
        data = f.read()
    count = len(data) // 8
    return struct.unpack(f'{count}d', data)

print("=== Reference Data Inspection ===")
print("\nInitial positions (x.double):")
data_x = load_doubles('grav_data/n1000/x.double')
print(f"  Count: {len(data_x)}")
print(f"  First 3 values: {data_x[:3]}")
print(f"  Min: {min(data_x):.6e}, Max: {max(data_x):.6e}")

print("\nReference final positions (resx.double):")
data_resx = load_doubles('grav_data/n1000/resx.double')
print(f"  Count: {len(data_resx)}")
print(f"  First 3 values: {data_resx[:3]}")
print(f"  Min: {min(data_resx):.6e}, Max: {max(data_resx):.6e}")

print("\nDifference (evolution from initial to final):")
if len(data_x) == len(data_resx):
    max_abs = max(abs(data_x[i] - data_resx[i]) for i in range(len(data_x)))
    mean_abs = sum(abs(data_x[i] - data_resx[i]) for i in range(len(data_x))) / len(data_x)
    print(f"  Max change:  {max_abs:.6e}")
    print(f"  Mean change: {mean_abs:.6e}")
