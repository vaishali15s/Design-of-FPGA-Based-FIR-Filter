`timescale 1ns / 1ps

module top_wrapper_tb;

    localparam FPGA_CLK_PERIOD_NS = 10;
    localparam SPI_HALF_PERIOD_NS = 20;

    reg clk;
    reg rst_n;
    reg sclk;
    reg cs_n;
    reg mosi;
    wire [15:0] filtered_out;
    wire filter_dv;

    integer filter_count;
    integer failures;
    reg waiting_for_filter;

    top_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .filtered_out(filtered_out),
        .filter_dv(filter_dv)
    );

    always #(FPGA_CLK_PERIOD_NS / 2) clk = ~clk;

    always @(posedge clk) begin
        if (filter_dv) begin
            filter_count = filter_count + 1;
            if (^filtered_out === 1'bx) begin
                $display("ERROR: filtered_out is unknown at %0t ns", $time);
                failures = failures + 1;
            end else begin
                $display("PASS: filter_dv at %0t ns, filtered_out = 0x%04h", $time, filtered_out);
            end
            waiting_for_filter = 1'b0;
        end
    end

    // SPI mode 0, MSB first. MOSI is set while SCLK is low and sampled on rising edge.
    task send_word;
        input [15:0] word;
        integer bit_index;
        begin
            waiting_for_filter = 1'b1;
            cs_n = 1'b0;
            sclk = 1'b0;

            for (bit_index = 15; bit_index >= 0; bit_index = bit_index - 1) begin
                mosi = word[bit_index];
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b1;
                #(SPI_HALF_PERIOD_NS);
                sclk = 1'b0;
            end

            mosi = 1'b0;
            cs_n = 1'b1;
            repeat (8) @(posedge clk);
            #1;

            if (waiting_for_filter) begin
                $display("ERROR: no filter_dv for SPI word 0x%04h", word);
                failures = failures + 1;
                waiting_for_filter = 1'b0;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sclk = 1'b0;
        cs_n = 1'b1;
        mosi = 1'b0;
        filter_count = 0;
        failures = 0;
        waiting_for_filter = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        send_word(16'h1000);
        send_word(16'hF000);

        if (filter_count != 2) begin
            $display("ERROR: expected 2 filter_dv pulses, received %0d", filter_count);
            failures = failures + 1;
        end

        if (failures == 0)
            $display("TOP WRAPPER TEST PASSED");
        else
            $display("TOP WRAPPER TEST FAILED: %0d failures", failures);

        $finish;
    end

endmodule
