`timescale 1ns/1ps
`define CYCLE 20

module tb_Toptest;

    logic i_clk;
    logic i_rst;

    logic i_clk_100k;
    logic o_i2c_sclk;
    wire io_i2c_sdat;
    logic tb_drive_sda;

    logic i_ps2_clk;
    logic i_ps2_data;

    logic sample_clk;

    logic i_bclk;
    logic i_daclrck;
    logic o_aud_data;

    assign io_i2c_sdat = tb_drive_sda ? 1'b0 : 1'bz;

    Toptest test(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_clk_100k(i_clk_100k),
        .o_i2c_sclk(o_i2c_sclk),
        .io_i2c_sdat(io_i2c_sdat),
        .i_ps2_clk(i_ps2_clk),
        .i_ps2_data(i_ps2_data),
        .sample_clk(sample_clk),
        .i_bclk(i_bclk),
        .i_daclrck(i_daclrck),
        .o_aud_data(o_aud_data)
    );

    task send_ps2_frame(input [7:0] data_byte);
        integer i;
        reg parity;

        begin
            // 計算 odd parity
            parity = ^data_byte; // XOR → even parity
            parity = ~parity;    // invert → odd parity

            // start bit
            @(negedge i_ps2_clk);
            i_ps2_data = 0;

            // data bits (LSB first)
            for(i = 0; i <= 7; i=i+1) begin
                @(negedge i_ps2_clk);
                i_ps2_data = data_byte[i];
            end

            // parity bit
            @(negedge i_ps2_clk);
            i_ps2_data = parity;

            // stop bit
            @(negedge i_ps2_clk);
            i_ps2_data = 1;

            // idle
            repeat(5) @(negedge i_ps2_clk);
        end
    endtask

    initial begin
        i_clk = 1'b1;
        i_clk_100k = 1'b1;
        sample_clk = 1'b1;
        i_bclk = 1'b1;
        i_daclrck = 1'b1;
        i_ps2_clk = 1'b1;
    end

    always #10 i_clk = ~i_clk;
    always #5000 i_clk_100k = ~i_clk_100k;
    always #10000 sample_clk = ~sample_clk;
    always #320 i_bclk = ~i_bclk;
    always #10000 i_daclrck = ~i_daclrck;
    always #50000 i_ps2_clk = ~i_ps2_clk;

    initial begin
        i_rst = 1'b0;
        i_ps2_data = 1'b1;
        tb_drive_sda = 1'b0;

        #(`CYCLE * 1) i_rst = 1'b1;
        #(`CYCLE * 3) i_rst = 1'b0;
        @(negedge o_i2c_sclk);    // 第 9 個 clock
        #1 tb_drive_sda = 1;         // TB 拉低 SDA = ACK
        @(negedge o_i2c_sclk);
        tb_drive_sda = 0;         // 釋放 SDA

        #(`CYCLE * 1000000);
        send_ps2_frame(8'h43);
        send_ps2_frame(8'hf0);
        send_ps2_frame(8'h43);
        send_ps2_frame(8'h1c);
        send_ps2_frame(8'h34);
        send_ps2_frame(8'hf0);
        send_ps2_frame(8'h1c);
        send_ps2_frame(8'hf0);
        send_ps2_frame(8'h34);
        send_ps2_frame(8'h43);
        send_ps2_frame(8'hf0);
        send_ps2_frame(8'h43);
    end

    initial begin
        $fsdbDumpfile("test.fsdb");
        $fsdbDumpvars;
    end
    initial #(`CYCLE*10000000) $finish;

endmodule