/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "i2c.h"
#include "spi.h"
#include "tim.h"
#include "usart.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "mpu6050.h"
#include <stdio.h>
#include <string.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/

/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
volatile uint8_t timer_flag = 0;
uint8_t tx_buffer[64];
MPU6050_Data_t mpu_data;
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
void SPI_Send_Sample(int16_t sample)
{
    uint8_t bytes[2];
    bytes[0] = (uint8_t)((sample >> 8) & 0xFF); // High Byte (MSB)
    bytes[1] = (uint8_t)(sample & 0xFF);        // Low Byte (LSB)

    // Pull CS LOW (PA4)
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_RESET);

    // Transmit 2 bytes over SPI1
    HAL_SPI_Transmit(&hspi1, bytes, 2, 10);

    // Pull CS HIGH (PA4)
    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4, GPIO_PIN_SET);
}
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_TIM2_Init();
  MX_USART2_UART_Init();
  MX_SPI1_Init();
  /* USER CODE BEGIN 2 */
  // 1. Send startup confirmation over UART
    char msg[64];
    int len = sprintf(msg, "MCU_STARTED\r\n");
    HAL_UART_Transmit(&huart2, (uint8_t*)msg, len, 100);

    // 2. Scan I2C bus for MPU6050 address (0x68 or 0x69)
    uint8_t mpu_addr = 0;
    for (uint8_t addr = 1; addr < 128; addr++)
    {
        if (HAL_I2C_IsDeviceReady(&hi2c1, (uint16_t)(addr << 1), 2, 50) == HAL_OK)
        {
            mpu_addr = (addr << 1); // Save 8-bit shifted address
            len = sprintf(msg, "FOUND_SENSOR_AT_0x%02X\r\n", addr);
            HAL_UART_Transmit(&huart2, (uint8_t*)msg, len, 100);
            break;
        }
    }

    if (mpu_addr == 0)
    {
        len = sprintf(msg, "ERROR_NO_I2C_SENSOR_RESPONDED\r\n");
        HAL_UART_Transmit(&huart2, (uint8_t*)msg, len, 100);
    }
    else
    {
        // 3. Sensor found! Wake it up with 100ms timeout so it CANNOT hang
        uint8_t wake_data = 0x00;
        HAL_I2C_Mem_Write(&hi2c1, mpu_addr, 0x6B, 1, &wake_data, 1, 100); // PWR_MGMT_1

        uint8_t config_data = 0x00; // ±2g scale
        HAL_I2C_Mem_Write(&hi2c1, mpu_addr, 0x1C, 1, &config_data, 1, 100); // ACCEL_CONFIG

        len = sprintf(msg, "SENSOR_INITIALIZED_SUCCESSFULLY\r\n");
        HAL_UART_Transmit(&huart2, (uint8_t*)msg, len, 100);

        // Start 500 Hz Timer interrupt
        HAL_TIM_Base_Start_IT(&htim2);
    }
  /* USER CODE END 2 */

  /* Initialize leds */
//  BSP_LED_Init(LED2);

  /* Initialize USER push-button, will be used to trigger an interrupt each time it's pressed.*/
//  BSP_PB_Init(BUTTON_USER, BUTTON_MODE_EXTI);

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
    while (1)
      {
          if (timer_flag)
          {
              timer_flag = 0;

              if (mpu_addr != 0)
              {
                  // Read 6 accelerometer bytes directly from sensor (0x3B = ACCEL_XOUT_H)
                  uint8_t raw_buf[6];
                  if (HAL_I2C_Mem_Read(&hi2c1, mpu_addr, 0x3B, 1, raw_buf, 6, 50) == HAL_OK)
                  {
                      // Combine Z-axis high and low bytes (Registers 0x3F & 0x40)
                      int16_t raw_z = (int16_t)((raw_buf[4] << 8) | raw_buf[5]);

                      len = sprintf((char*)tx_buffer, "%d\r\n", raw_z);
                      HAL_UART_Transmit(&huart2, tx_buffer, len, 10);
                      // 2. Send via SPI to FPGA!
                      SPI_Send_Sample(raw_z);
                  }
              }
          }
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 16;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
  RCC_OscInitStruct.PLL.PLLQ = 2;
  RCC_OscInitStruct.PLL.PLLR = 2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM2)
    {
        timer_flag = 1; // Flag main loop to execute I2C read
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
