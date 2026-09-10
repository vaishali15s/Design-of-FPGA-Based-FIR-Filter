module top_wrapper (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sclk,
    input  wire        cs_n,
    input  wire        mosi,
    output wire [15:0] filtered_out,
    output wire        filter_dv
);

    wire [15:0] rx_data;
    wire        rx_dv;

    spi_slave #(
        .DATA_WIDTH(16)
    ) u_spi_slave (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rx_data(rx_data),
        .rx_dv(rx_dv)
    );

    fir_filter #(
        .DATA_WIDTH(16),
        .COEFF_WIDTH(16),
        .NUM_TAPS(64)
    ) u_fir_filter (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(rx_dv),
        .din(rx_data),
        .dout(filtered_out)
    );

    assign filter_dv = rx_dv;

endmodule
