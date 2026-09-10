module spi_slave #(
    parameter DATA_WIDTH = 16
)(
    input  wire                    clk,       // FPGA system clock
    input  wire                    rst_n,     // Active-low system reset
    input  wire                    sclk,      // SPI Clock from STM32 (Master)
    input  wire                    cs_n,      // Chip Select from STM32 (Active Low)
    input  wire                    mosi,      // Master Out Slave In
    output reg  [DATA_WIDTH-1:0]   rx_data,   // Received 16-bit parallel data
    output reg                     rx_dv      // Data Valid pulse (1 clock cycle)
);

    // 2-stage synchronizers for asynchronous SPI signals
    reg [1:0] sclk_sync;
    reg [1:0] cs_n_sync;
    reg [1:0] mosi_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 2'b11;
            cs_n_sync <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[0], sclk};
            cs_n_sync <= {cs_n_sync[0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    // Detect rising edge of synchronized SCLK (SPI Mode 0 sampling)
    wire sclk_rising = (sclk_sync == 2'b01);
    // Detect active low chip select
    wire cs_active   = (cs_n_sync[1] == 1'b0);

    reg [DATA_WIDTH-1:0] shift_reg;
    reg [4:0]            bit_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {DATA_WIDTH{1'b0}};
            rx_data   <= {DATA_WIDTH{1'b0}};
            rx_dv     <= 1'b0;
            bit_cnt   <= 5'd0;
        end else begin
            rx_dv <= 1'b0; // Default pulse low

            if (cs_active) begin
                if (sclk_rising) begin
                    // Shift in MSB first
                    shift_reg <= {shift_reg[DATA_WIDTH-2:0], mosi_sync[1]};
                    bit_cnt   <= bit_cnt + 1'b1;

                    // Once 16 bits are fully shifted in
                    if (bit_cnt == DATA_WIDTH - 1) begin
                        rx_data <= {shift_reg[DATA_WIDTH-2:0], mosi_sync[1]};
                        rx_dv   <= 1'b1;
                        bit_cnt <= 5'd0;
                    end
                end
            end else begin
                // Reset bit counter if chip select goes high mid-transmission
                bit_cnt <= 5'd0;
            end
        end
    end

endmodule