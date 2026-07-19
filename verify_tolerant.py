import struct
import sys

def load_doubles(path):
    with open(path, 'rb') as f:
        data = f.read()
    count = len(data) // 8
    return struct.unpack(f'{count}d', data)

def compare(p1, p2, tol=1e-10):
    d1 = load_doubles(p1)
    d2 = load_doubles(p2)
    if len(d1) != len(d2):
        print(f"❌ Length mismatch between {p1} and {p2}: {len(d1)} vs {len(d2)}")
        return False
    
    max_diff = 0.0
    for i, (v1, v2) in enumerate(zip(d1, d2)):
        diff = abs(v1 - v2)
        if diff > max_diff:
            max_diff = diff
            
    print(f"Max absolute difference between {p1} and {p2}: {max_diff:.6e}")
    if max_diff < tol:
        print(f"✓ {p1} and {p2} match within tolerance {tol:.0e}")
        return True
    else:
        print(f"❌ {p1} and {p2} exceed tolerance {tol:.0e} (Max diff: {max_diff:.6e})")
        return False

ok = compare('output_x_aos.double', 'output_x_soa.double') and \
     compare('output_y_aos.double', 'output_y_soa.double') and \
     compare('output_z_aos.double', 'output_z_soa.double')

sys.exit(0 if ok else 1)
