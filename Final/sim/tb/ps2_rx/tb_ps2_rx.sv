`timescale 1us/1ns

module tb_ps2_rx;

    logic clk;
    logic rst;
    logic ps2_clk;
    logic ps2_data;
    logic [7:0] o_data;
    logic       o_valid;

    // instantiate DUT
    ps2_rx dut(
        .i_clk(clk),
        .i_rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .o_data(o_data),
        .o_valid(o_valid)
    );

    // generate main FPGA system clock
    // assume 50MHz → period 0.02us = 20ns
    always #0.02 clk = ~clk;

    // generate ps2 clock (~30kHz → period ≈ 33us)
    always #16.5 ps2_clk = ~ps2_clk;


    // Task：送一個 PS/2 frame（11 bits）
    // 格式： start(0) + 8bit data + parity + stop(1)
    task send_ps2_frame(input [7:0] data_byte);
        integer i;
        reg parity;

        begin
            // 計算 odd parity
            parity = ^data_byte; // XOR → even parity
            parity = ~parity;    // invert → odd parity

            // start bit
            @(negedge ps2_clk);
            ps2_data = 0;

            // data bits (LSB first)
            for(i = 7; i >= 0; i=i-1) begin
                @(negedge ps2_clk);
                ps2_data = data_byte[i];
            end

            // parity bit
            @(negedge ps2_clk);
            ps2_data = parity;

            // stop bit
            @(negedge ps2_clk);
            ps2_data = 1;

            // idle
            repeat(5) @(negedge ps2_clk);
        end
    endtask


    initial begin
        // initial values
        clk = 0;
        ps2_clk = 1;
        ps2_data = 1;

        rst = 1;
        #1;
        rst = 0;

        $display("=== Start PS/2 RX Test ===");

        // 傳送字母 A 的 make code → 1C
        $display("[SEND] Make: 1C");
        send_ps2_frame(8'h1C);

        // 傳送 break code → F0
        $display("[SEND] Break: F0");
        send_ps2_frame(8'hF0);

        // 傳送字母 A 的 break code → 1C
        $display("[SEND] KeyRelease: 1C");
        send_ps2_frame(8'h1C);

        #2000;
        $display("=== Test Finished ===");
        $finish;
    end


    // monitor output
    //always @(posedge clk) begin
    //    if(o_valid)
    //        $display("[VALID] time=%0t  data=%02h", $time, o_data);
    //end

    initial begin
        $fsdbDumpfile("tb_ps2_rx.fsdb");
        $fsdbDumpvars;
    end

endmodule
