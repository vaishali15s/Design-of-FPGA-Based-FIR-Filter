with open("sensor_vibration_dataset.csv", "r") as f:
    raw_hex = [line.strip() for line in f if line.strip()]

# Convert hex to decimal integers
data_dec = [int(val, 16) for val in raw_hex]





