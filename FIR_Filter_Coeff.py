import numpy as np
from scipy import signal

# Generate 64 coefficients for a 25 Hz low-pass filter at 1000 Hz sampling rate
b = signal.firwin(64, 25, fs=1000, window='hamming')
b_q15 = [int(round(val * 32767)) for val in b]
print(b_q15)