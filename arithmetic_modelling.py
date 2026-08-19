import numpy as np
from fxpmath import Fxp

# --- STEP 1: Define your coefficients (Simulating output from MATLAB) ---
h_float = np.array([0.02, 0.08, 0.18, 0.22, 0.22, 0.18, 0.08, 0.02])

# --- STEP 2: Use fxpmath with explicit keyword arguments for Q15 ---
# Signed = True, Word length = 16 bits, Fractional bits = 15
h_fixed = Fxp(h_float, signed=True, n_word=16, n_frac=15)

print("--- Q15 COEFFICIENTS FOR VERILOG ---")
print("Decimal values:", h_fixed.val)
print("Hex values:    ", h_fixed.hex())
print("Binary values: ", h_fixed.bin())

# --- STEP 3: Simulating 16-bit Data & 8-bit SPI Chunking ---
sample_float = 0.5
sample_fxp = Fxp(sample_float, signed=True, n_word=16, n_frac=15)

# Get the raw underlying 16-bit integer representation safely using .val
raw_16bit = int(sample_fxp.val) & 0xFFFF

print("\n--- SPI BYTE CHUNKING SIMULATION ---")
print(f"Original Sample Value: {sample_float}")
print(f"16-bit Hex Word:       {hex(raw_16bit)}")

# Split the 16-bit word into two 8-bit bytes for SPI transmission
high_byte = (raw_16bit >> 8) & 0xFF
low_byte = raw_16bit & 0xFF

print(f"Byte 1 (High Byte):    {hex(high_byte)}")
print(f"Byte 2 (Low Byte):     {hex(low_byte)}")

# Reassembly check (what your Verilog SPI slave will do)
reassembled_16bit = (high_byte << 8) | low_byte
print(f"Reassembled in Verilog: {hex(reassembled_16bit)}")