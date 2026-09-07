`timescale 1ns / 1ps

module fir_filter #(
    parameter DATA_WIDTH = 16,
    parameter COEFF_WIDTH = 16,
    parameter NUM_TAPS = 64
)(
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire signed [DATA_WIDTH-1:0] din,
    output reg signed [DATA_WIDTH-1:0] dout
);

    // Q1.15 coefficients for a 64-tap, 25 Hz low-pass filter at 1 kHz.
    // The coefficients were generated with a Hamming window and are
    // represented as signed 16-bit integers.
    reg signed [COEFF_WIDTH-1:0] h [0:NUM_TAPS-1];
    initial begin
        h[0]  = -16'sd26;   h[1]  = -16'sd28;   h[2]  = -16'sd32;   h[3]  = -16'sd36;
        h[4]  = -16'sd41;   h[5]  = -16'sd46;   h[6]  = -16'sd50;   h[7]  = -16'sd52;
        h[8]  = -16'sd51;   h[9]  = -16'sd45;   h[10] = -16'sd33;   h[11] = -16'sd13;
        h[12] = 16'sd16;    h[13] = 16'sd55;    h[14] = 16'sd106;   h[15] = 16'sd169;
        h[16] = 16'sd244;   h[17] = 16'sd330;   h[18] = 16'sd428;   h[19] = 16'sd535;
        h[20] = 16'sd650;   h[21] = 16'sd771;   h[22] = 16'sd895;   h[23] = 16'sd1019;
        h[24] = 16'sd1140;  h[25] = 16'sd1255;  h[26] = 16'sd1360;  h[27] = 16'sd1453;
        h[28] = 16'sd1531;  h[29] = 16'sd1592;  h[30] = 16'sd1633;  h[31] = 16'sd1655;
        h[32] = 16'sd1655;  h[33] = 16'sd1633;  h[34] = 16'sd1592;  h[35] = 16'sd1531;
        h[36] = 16'sd1453;  h[37] = 16'sd1360;  h[38] = 16'sd1255;  h[39] = 16'sd1140;
        h[40] = 16'sd1019;  h[41] = 16'sd895;   h[42] = 16'sd771;   h[43] = 16'sd650;
        h[44] = 16'sd535;   h[45] = 16'sd428;   h[46] = 16'sd330;   h[47] = 16'sd244;
        h[48] = 16'sd169;   h[49] = 16'sd106;   h[50] = 16'sd55;    h[51] = 16'sd16;
        h[52] = -16'sd13;   h[53] = -16'sd33;   h[54] = -16'sd45;   h[55] = -16'sd51;
        h[56] = -16'sd52;   h[57] = -16'sd50;   h[58] = -16'sd46;   h[59] = -16'sd41;
        h[60] = -16'sd36;   h[61] = -16'sd32;   h[62] = -16'sd28;   h[63] = -16'sd26;
    end

    // Shift register delay line for input samples
    reg signed [DATA_WIDTH-1:0] shift_reg [0:NUM_TAPS-1];
    
    // Internal accumulator with extra bit width to prevent overflow during MAC operations
    reg signed [DATA_WIDTH + COEFF_WIDTH + 6:0] acc;
    reg signed [DATA_WIDTH + COEFF_WIDTH - 1:0] product;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                shift_reg[i] <= {DATA_WIDTH{1'b0}};
            end
            dout <= {DATA_WIDTH{1'b0}};
        end else if (sample_valid) begin
            // Shift incoming data down the delay line
            shift_reg[0] <= din;
            for (i = 1; i < NUM_TAPS; i = i + 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end

            // Multiply-Accumulate (MAC) calculation
            acc = 0;
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                product = shift_reg[i] * h[i];
                acc = acc + product;
            end

            // Rescale from Q30 back to Q15 format and assign to output
            dout <= acc >>> 15;
        end
    end

endmodule