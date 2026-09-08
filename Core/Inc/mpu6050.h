#ifndef INC_MPU6050_H_
#define INC_MPU6050_H_

#include "stm32f4xx_hal.h"  // Adjust header if using another STM32 series (e.g., stm32f1xx_hal.h)

/* =========================================================================
 * I2C ADDRESSES & REGISTER MAP (MPU-6050)
 * ========================================================================= */
#define MPU6050_I2C_ADDR         (0x69 << 1) // 7-bit 0x68 shifted to 8-bit write address (0xD0)

/* Registers */
#define MPU6050_REG_SMPLRT_DIV   0x19        // Sample Rate Divider
#define MPU6050_REG_CONFIG       0x1A        // DLPF Configuration
#define MPU6050_REG_GYRO_CONFIG  0x1B        // Gyroscope Configuration
#define MPU6050_REG_ACCEL_CONFIG 0x1C        // Accelerometer Configuration
#define MPU6050_REG_ACCEL_XOUT_H 0x3B        // Accel Data start register
#define MPU6050_REG_TEMP_OUT_H   0x41        // Temperature Data start register
#define MPU6050_REG_GYRO_XOUT_H  0x43        // Gyro Data start register
#define MPU6050_REG_PWR_MGMT_1   0x6B        // Power Management 1
#define MPU6050_REG_WHO_AM_I     0x75        // Device ID register (Should return 0x68)

/* Expected Device ID */
#define MPU6050_WHO_AM_I_VAL     0x68

/* Scale Factors for Default Ranges (+/-2g for Accel, +/-250 deg/s for Gyro) */
#define MPU6050_ACCEL_SENS_2G    16384.0f
#define MPU6050_GYRO_SENS_250    131.0f

/* =========================================================================
 * DATA STRUCTURES
 * ========================================================================= */

// Scaled sensor measurements in physical units
typedef struct {
    float accel_x_g;     // Acceleration in g (1g = 9.81 m/s^2)
    float accel_y_g;
    float accel_z_g;

    float gyro_x_dps;   // Gyroscope in degrees per second (°/s)
    float gyro_y_dps;
    float gyro_z_dps;

    float temp_c;        // Temperature in Celsius (°C)
} MPU6050_Data_t;

/* =========================================================================
 * DRIVER FUNCTION PROTOTYPES
 * ========================================================================= */

/**
 * @brief  Initializes MPU6050 sensor (Verifies WHO_AM_I and wakes device from sleep)
 * @param  hi2c: Pointer to STM32 HAL I2C handle
 * @return HAL_OK if successful, HAL_ERROR otherwise
 */
HAL_StatusTypeDef MPU6050_Init(I2C_HandleTypeDef *hi2c);

/**
 * @brief  Reads all raw data (Accel, Temp, Gyro) and converts them into physical units
 * @param  hi2c: Pointer to STM32 HAL I2C handle
 * @param  data: Pointer to MPU6050_Data_t structure where converted data will be stored
 * @return HAL_OK if successful, HAL_ERROR otherwise
 */
HAL_StatusTypeDef MPU6050_ReadAll(I2C_HandleTypeDef *hi2c, MPU6050_Data_t *data);

#endif /* INC_MPU6050_H_ */
