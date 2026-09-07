`timescale 1ns / 1ps

module tb_fir_filter;

    parameter DATA_WIDTH = 16;
    parameter COEFF_WIDTH = 16;
    parameter NUM_TAPS = 64;
    parameter CLK_PERIOD_NS = 20;
    parameter CLOCKS_PER_SAMPLE = 20; // 50 MHz clock / 1 kHz sample rate
    parameter NUM_TONE_SAMPLES = 512;
    parameter NUM_SENSOR_SAMPLES = 256;
    parameter SENSOR_MEMORY_SIZE = 1000;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg signed [DATA_WIDTH-1:0] din;
    wire signed [DATA_WIDTH-1:0] dout;
    reg [DATA_WIDTH-1:0] sensor_data [0:SENSOR_MEMORY_SIZE-1];

    integer file_12hz;
    integer file_100hz;
    integer file_sensor;
    integer i;
    integer sample;
    integer output_sample;
    real sum_input_sq;
    real sum_output_sq;
    real input_rms;
    real output_rms;
    real phase;

    fir_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_TAPS(NUM_TAPS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .din(din),
        .dout(dout)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // Hold each input sample for 20 FPGA clocks, giving a 1 kHz sample rate.
    task send_sample;
        input integer value;
        begin
            din = value;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            sample_valid = 1'b0;
            repeat (CLOCKS_PER_SAMPLE - 1) @(posedge clk);
            #1;
        end
    endtask

    task reset_filter;
        begin
            rst_n = 1'b0;
            din = 16'sd0;
            sample_valid = 1'b0;
            repeat (3) @(posedge clk);
            rst_n = 1'b1;
            repeat (NUM_TAPS * CLOCKS_PER_SAMPLE) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        din = 16'sd0;
        sample_valid = 1'b0;
        $readmemh("sensor_data.mem", sensor_data);

        // 12 Hz: expected to pass through the 25 Hz low-pass filter.
        reset_filter;
        file_12hz = $fopen("fir_12hz_results.csv", "w");
        $fwrite(file_12hz, "sample,input,output\n");
        sum_input_sq = 0;
        sum_output_sq = 0;
        for (i = 0; i < NUM_TONE_SAMPLES; i = i + 1) begin
            phase = 2.0 * 3.141592653589793 * 12.0 * i / 1000.0;
            sample = $rtoi(10000.0 * $sin(phase));
            send_sample(sample);
            output_sample = $signed(dout);
            $fwrite(file_12hz, "%0d,%0d,%0d\n", i, sample, output_sample);
            if (i >= NUM_TAPS) begin
                sum_input_sq = sum_input_sq + sample * sample;
                sum_output_sq = sum_output_sq + output_sample * output_sample;
            end
        end
        input_rms = $sqrt(sum_input_sq * 1.0 / (NUM_TONE_SAMPLES - NUM_TAPS));
        output_rms = $sqrt(sum_output_sq * 1.0 / (NUM_TONE_SAMPLES - NUM_TAPS));
        $display("12 Hz passband: input RMS = %0.2f, output RMS = %0.2f, gain = %0.4f",
                 input_rms, output_rms, output_rms / input_rms);
        if ((output_rms / input_rms) > 0.8)
            $display("12 Hz result: PASS (signal is preserved)");
        else
            $display("12 Hz result: FAIL (unexpected passband loss)");
        $fclose(file_12hz);

        // 100 Hz: expected to be strongly attenuated by the 25 Hz filter.
        reset_filter;
        file_100hz = $fopen("fir_100hz_results.csv", "w");
        $fwrite(file_100hz, "sample,input,output\n");
        sum_input_sq = 0;
        sum_output_sq = 0;
        for (i = 0; i < NUM_TONE_SAMPLES; i = i + 1) begin
            phase = 2.0 * 3.141592653589793 * 100.0 * i / 1000.0;
            sample = $rtoi(10000.0 * $sin(phase));
            send_sample(sample);
            output_sample = $signed(dout);
            $fwrite(file_100hz, "%0d,%0d,%0d\n", i, sample, output_sample);
            if (i >= NUM_TAPS) begin
                sum_input_sq = sum_input_sq + sample * sample;
                sum_output_sq = sum_output_sq + output_sample * output_sample;
            end
        end
        input_rms = $sqrt(sum_input_sq * 1.0 / (NUM_TONE_SAMPLES - NUM_TAPS));
        output_rms = $sqrt(sum_output_sq * 1.0 / (NUM_TONE_SAMPLES - NUM_TAPS));
        $display("100 Hz stopband: input RMS = %0.2f, output RMS = %0.2f, gain = %0.4f",
                 input_rms, output_rms, output_rms / input_rms);
        if ((output_rms / input_rms) < 0.1)
            $display("100 Hz result: PASS (noise is attenuated)");
        else
            $display("100 Hz result: FAIL (insufficient stopband attenuation)");
        $fclose(file_100hz);

        // Replay the first sensor samples through the same filter.
        reset_filter;
        file_sensor = $fopen("fir_sensor_results.csv", "w");
        $fwrite(file_sensor, "sample,input,output\n");
        for (i = 0; i < NUM_SENSOR_SAMPLES; i = i + 1) begin
            sample = $signed(sensor_data[i]);
            send_sample(sample);
            output_sample = $signed(dout);
            $fwrite(file_sensor, "%0d,%0d,%0d\n", i, sample, output_sample);
        end
        $fclose(file_sensor);
        $display("Sensor test: processed %0d samples; results written to fir_sensor_results.csv",
                 NUM_SENSOR_SAMPLES);

        $finish;
    end

endmodule
