#include "mpu6050.h"

/**
 * @brief  Initialize MPU6050
 */
HAL_StatusTypeDef MPU6050_Init(I2C_HandleTypeDef *hi2c) {
    uint8_t check = 0;
    uint8_t data = 0;

    // 1. Check WHO_AM_I register to verify sensor presence
    if (HAL_I2C_Mem_Read(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_WHO_AM_I, 1, &check, 1, 100) != HAL_OK) {
        return HAL_ERROR;
    }
/*   if (check != 0x68 && check != 0x70) {
        return HAL_ERROR; // Device ID mismatch!
    } */

    // 2. Wake device up from sleep mode by clearing bit 6 in PWR_MGMT_1 register
    data = 0x00;
    if (HAL_I2C_Mem_Write(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_PWR_MGMT_1, 1, &data, 1, 100) != HAL_OK) {
        return HAL_ERROR;
    }

    // 3. Set Sample Rate Divider to 1 kHz (SMPLRT_DIV = 7)
    data = 0x07;
    HAL_I2C_Mem_Write(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_SMPLRT_DIV, 1, &data, 1, 100);

    // 4. Configure Full Scale Range: Accel +/- 2g (0x00) & Gyro +/- 250 deg/s (0x00)
    data = 0x00;
    HAL_I2C_Mem_Write(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_ACCEL_CONFIG, 1, &data, 1, 100);
    HAL_I2C_Mem_Write(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_GYRO_CONFIG, 1, &data, 1, 100);

    return HAL_OK;
}

/**
 * @brief  Read Accelerometer, Temperature, and Gyroscope data in a single 14-byte burst
 */
HAL_StatusTypeDef MPU6050_ReadAll(I2C_HandleTypeDef *hi2c, MPU6050_Data_t *data) {
    uint8_t raw_buffer[14];

    // Read 14 sequential bytes starting from ACCEL_XOUT_H (0x3B) down through GYRO_ZOUT_L (0x44)
    if (HAL_I2C_Mem_Read(hi2c, MPU6050_I2C_ADDR, MPU6050_REG_ACCEL_XOUT_H, 1, raw_buffer, 14, 100) != HAL_OK) {
        return HAL_ERROR;
    }

    /* ---------------------------------------------------------------------
     * RECONSTRUCT 16-BIT SIGNED INTEGERS FROM HIGH/LOW BYTE PAIRS
     * --------------------------------------------------------------------- */
    int16_t raw_accel_x = (int16_t)((raw_buffer[0]  << 8) | raw_buffer[1]);
    int16_t raw_accel_y = (int16_t)((raw_buffer[2]  << 8) | raw_buffer[3]);
    int16_t raw_accel_z = (int16_t)((raw_buffer[4]  << 8) | raw_buffer[5]);

    int16_t raw_temp    = (int16_t)((raw_buffer[6]  << 8) | raw_buffer[7]);

    int16_t raw_gyro_x  = (int16_t)((raw_buffer[8]  << 8) | raw_buffer[9]);
    int16_t raw_gyro_y  = (int16_t)((raw_buffer[10] << 8) | raw_buffer[11]);
    int16_t raw_gyro_z  = (int16_t)((raw_buffer[12] << 8) | raw_buffer[13]);

    /* ---------------------------------------------------------------------
     * CONVERT TO PHYSICAL UNITS
     * --------------------------------------------------------------------- */
    // Accelerometer conversion (in g's)
    data->accel_x_g = (float)raw_accel_x / MPU6050_ACCEL_SENS_2G;
    data->accel_y_g = (float)raw_accel_y / MPU6050_ACCEL_SENS_2G;
    data->accel_z_g = (float)raw_accel_z / MPU6050_ACCEL_SENS_2G;

    // Temperature formula from datasheet: Temperature in °C = (RAW / 340.0) + 36.53
    data->temp_c    = ((float)raw_temp / 340.0f) + 36.53f;

    // Gyroscope conversion (in degrees per second)
    data->gyro_x_dps = (float)raw_gyro_x / MPU6050_GYRO_SENS_250;
    data->gyro_y_dps = (float)raw_gyro_y / MPU6050_GYRO_SENS_250;
    data->gyro_z_dps = (float)raw_gyro_z / MPU6050_GYRO_SENS_250;

    return HAL_OK;
}
