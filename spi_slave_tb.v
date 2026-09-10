`timescale 1ns / 1ps

module spi_slave_tb;

    localparam DATA_WIDTH = 16;
    localparam FPGA_CLK_PERIOD_NS = 10;
    localparam SPI_HALF_PERIOD_NS = 20;

    reg clk;
    reg rst_n;
    reg sclk;
    reg cs_n;
    reg mosi;
    wire [DATA_WIDTH-1:0] rx_data;
    wire rx_dv;

    integer checks;
    integer failures;
    integer dv_count;
    reg [DATA_WIDTH-1:0] expected_data;
    reg waiting_for_word;
    reg incomplete_frame;

    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rx_data(rx_data),
        .rx_dv(rx_dv)
    );

    always #(FPGA_CLK_PERIOD_NS / 2) clk = ~clk;

    // Check each received word when the slave pulses rx_dv.
    always @(posedge clk) begin
        if (rx_dv) begin
            dv_count = dv_count + 1;
            checks = checks + 1;

            if (!waiting_for_word) begin
                $display("ERROR: unexpected rx_dv at %0t ns, data = 0x%04h", $time, rx_data);
                failures = failures + 1;
            end else if (rx_data !== expected_data) begin
                $display("ERROR: received 0x%04h, expected 0x%04h at %0t ns", rx_data, expected_data, $time);
                failures = failures + 1;
            end else begin
                $display("PASS: received 0x%04h at %0t ns", rx_data, $time);
            end

            waiting_for_word = 1'b0;
        end
    end

    // SPI mode 0: MOSI changes while SCLK is low and is sampled on rising edge.
    task send_word;
        input [DATA_WIDTH-1:0] word;
        integer bit_index;
        begin
            expected_data = word;
            waiting_for_word = 1'b1;
            cs_n = 1'b0;
            sclk = 1'b0;

            for (bit_index = DATA_WIDTH - 1; bit_index >= 0; bit_index = bit_index - 1) begin
                mosi = word[bit_index];
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b1;
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b0;
            end

            mosi = 1'b0;
            cs_n = 1'b1;

            // Allow the synchronized SCLK/CS signals to settle and rx_dv to pulse.
            repeat (8) @(posedge clk);
            #1;

            if (waiting_for_word) begin
                $display("ERROR: no rx_dv for word 0x%04h", word);
                failures = failures + 1;
                waiting_for_word = 1'b0;
            end
        end
    endtask

    // Send fewer than 16 bits and verify that no word is reported.
    task send_incomplete_frame;
        integer bit_index;
        begin
            incomplete_frame = 1'b1;
            cs_n = 1'b0;
            sclk = 1'b0;

            for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
                mosi = bit_index[0];
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b1;
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b0;
            end

            mosi = 1'b0;
            cs_n = 1'b1;
            repeat (8) @(posedge clk);
            #1;

            if (dv_count != 3) begin
                $display("ERROR: incomplete frame generated rx_dv");
                failures = failures + 1;
            end else begin
                $display("PASS: incomplete frame discarded");
            end
            incomplete_frame = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sclk = 1'b0;
        cs_n = 1'b1;
        mosi = 1'b0;
        checks = 0;
        failures = 0;
        dv_count = 0;
        expected_data = {DATA_WIDTH{1'b0}};
        waiting_for_word = 1'b0;
        incomplete_frame = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        // Positive, negative, and zero-valued signed sensor samples.
        send_word(16'h1234);
        send_word(16'h8001);
        send_word(16'h0000);
        send_incomplete_frame;

        if (dv_count != 3) begin
            $display("ERROR: expected 3 valid words, received %0d", dv_count);
            failures = failures + 1;
        end

        if (failures == 0)
            $display("SPI SLAVE TEST PASSED: %0d checks", checks);
        else
            $display("SPI SLAVE TEST FAILED: %0d failures", failures);

        $finish;
    end

endmodule
