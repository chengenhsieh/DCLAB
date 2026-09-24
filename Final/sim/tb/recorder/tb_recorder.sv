`timescale 1us/1ns
`define CYCLE 20.0
`define HCYCLE 10.0
`define GOLDENFILE "../tb/recorder/golden.txt" // File for golden data
`define PATTERN_NUM 16

module tb_recorder;
    integer fp_golden;
    logic [19:0] golden_data [0:15];

    logic clk;
    logic rst;
    logic start;
    logic [15:0] i_data;
    logic pause;
    logic stop;
    logic [25:0] address;
    logic [15:0] o_data;
    logic [25:0] stop_address;
    logic finish;

    recorder sim(
        .i_clk(clk),
        .i_rst(rst),
        .i_start(start),
        .i_data(i_data),
        .i_pause(pause),
        .i_stop(stop),
        .o_address(address),
        .o_data(o_data),
        .o_stop_address(stop_address),
        .o_finish(finish)
    );

    integer error;
    
    initial begin
        clk = 1'b1;
    end

    // 50 kHz -> T = 20 us
    always begin
        #(`HCYCLE) clk = ~clk;
    end

    task load_golden_data;
        input string file_name;
        integer status;
        begin
            fp_golden = $fopen(file_name, "rb");
            if (fp_golden == 0) begin
                $display("Error: Could not open golden data file.");
                $finish;
            end
            for (int i = 0; i < `PATTERN_NUM; i = i + 1) begin
                status = $fscanf(fp_golden, "%b\n", golden_data[i]);
            end
            $fclose(fp_golden);
        end
    endtask
    
    task save_error;
        input integer pattern;
        input integer bit_index;
        input bit recorder_out, golden_out;
        begin
            error = error + 1;
            $display("Error at pattern %0d bit %0d : recorder_out %b != golden_out %b", pattern, bit_index, recorder_out, golden_out);
        end
    endtask

    initial begin
        rst = 1'b0;
        start = 1'b0;
        i_data = 16'h0000;
        pause = 1'b0;
        stop = 1'b0;
        error = 0;
        load_golden_data(`GOLDENFILE);

        #(`CYCLE * 2.5) rst = 1'b1;
        #(`CYCLE * 3) rst = 1'b0;
        #(`CYCLE * 0.5) start = 1'b1;
        #(`CYCLE * 1) start = 1'b0;

        for(int i = 0; i < 16; i = i + 1) begin
            if(i == 2) begin
                #(`CYCLE * 0.5) pause = 1'b1;
                #(`CYCLE * 0.5) pause = 1'b0;
                #(`CYCLE * 0.5) start = 1'b1;
                #(`CYCLE * 0.5) start = 1'b0;
            end
            if(i == 4) begin
                #(`CYCLE * 0.5) stop = 1'b1;
            end
            @(negedge clk);
            i_data = golden_data[i];
            #(`CYCLE * 2);
            @(negedge clk)
            if( o_data != golden_data[i] ) begin
                error = error + 1;
                $display("==========================================");
                $display("Test pattern %0d", i);
                $display("Time             : %0d", $time);
                $display("Golden data      : %16b", golden_data[i]);
                $display("Recorded data    : %16b", o_data);
                $display("Recorded address : %20b", address);
                $display("==========================================");
            end
            #(`CYCLE * 2);
        end
        if (error == 0) begin
            $display("==========================================");
            $display("======  Congratulations! You Pass!  ======");
            $display("==========================================");
        end else begin
            $display("===============================");
            $display("There are %0d errors.", error);
            $display("===============================");
        end
        $finish;
    end

    initial begin
        $fsdbDumpfile("tb_recorder.fsdb");
        $fsdbDumpvars;
    end
    initial #(`CYCLE*10000000) $finish;
    
endmodule