module Toptest (
    input i_clk, // 50 MHz
    input i_rst, // map to key3
    input i_key_0, // start to record / stop to play
    input i_key_1, // record/audio pause
    input i_key_2, // record stop / play audio

    // i2c
    input i_clk_100k, // 100 kHz
    output o_i2c_sclk,
    inout io_i2c_sdat,

    // ps2
    input i_ps2_clk, // clk from ps2
    input i_ps2_data, // data from ps2

    // gen
    input sample_clk, // 50 kHz

    // SRAM
    output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N, // no need to handle
	output        o_SRAM_OE_N, // no need to handle
	output        o_SRAM_LB_N, // no need to handle
	output        o_SRAM_UB_N, // no need to handle

    // player
    input i_bclk, // 1.6 MHz
    input i_daclrck, // 50 kHz
    output o_aud_data,
	
	// LED
	output  [8:0] o_ledg,
	output [17:0] o_ledr, 

    output [5:0] o_time
);

parameter S_IDLE = 0;
parameter S_NORMAL = 1;
parameter S_RECORD = 2;
parameter S_PLAY = 3;

logic [1:0] state_r, state_w;

// i2c variable
logic i2c_start_r;
logic i2c_done, i2c_done_r, i2c_done_w;
logic i2c_oen;

// ps2 variable
logic [7:0] o_ps2_data, o_ps2_data_r, o_ps2_data_w;
logic o_ps2_valid, o_ps2_valid_r, o_ps2_valid_w;

// gen variable
logic gen_start_r, gen_start_w;
logic signed [15:0] o_gen_data, o_gen_data_r, o_gen_data_w;

// record variable
logic rec_start_r, rec_start_w;
logic rec_done, rec_done_r, rec_done_w;
logic rec_stop_r, rec_stop_w;
logic [19:0] o_rec_address;
logic [15:0] o_rec_data, o_rec_data_r, o_rec_data_w;
logic [19:0] o_rec_stop_address, o_rec_stop_address_r, o_rec_stop_address_w;

// player variable
logic player_start_r, player_start_w;
logic player_done, player_done_r, player_done_w;
logic player_pause_r, player_pause_w;
logic player_stop_r, player_stop_w;
logic [19:0] o_player_address;
logic o_en;
logic signed [15:0] i_aud_data_r, i_aud_data_w;

logic [19:0] read_address_r, read_address_w;
logic [15:0] data_play;


// led: state display
	// if state_r = S_IDLE,  then ledg = 9'b000000001
	// if state_r = S_NORMAL,  then ledg = 9'b000000010
	// if state_r = S_RECORD, then ledg = 9'b000000100
	// if state_r = S_PLAY, then ledg = 9'b000001000
	assign o_ledg = (state_r == S_IDLE) ? 9'b000000001 : 
				   (state_r == S_NORMAL) ? 9'b000000010 :
					(state_r == S_RECORD) ? 9'b000000100 : 9'b000001000;

I2cInitializer i2c(
    .i_clk(i_clk_100k),
    .i_rst(i_rst),
    .i_start(i2c_start_r),
    .o_sclk(o_i2c_sclk),
    .io_sdat(io_i2c_sdat),
    .o_oen(i2c_oen),
    .o_finished(i2c_done)
);

ps2_rx ps2(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .ps2_clk(i_ps2_clk),
    .ps2_data(i_ps2_data),
    .o_data(o_ps2_data),
    .o_valid(o_ps2_valid)
);

top gen0(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(gen_start_w),
    .i_valid_in(o_ps2_valid),
    .i_ps2_data(o_ps2_data),
    .o_audio_sample(o_gen_data)
);

recorder rec(
    .i_clk(i_clk),
    .sample_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(rec_start_r),
    .i_data(o_gen_data_r),
    .i_stop(rec_stop_r),
    .o_address(o_rec_address),
    .o_data(o_rec_data),
    .o_stop_address(o_rec_stop_address),
    .o_finish(rec_done)
);

player_controller controll(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .sample_clk(sample_clk),
    .i_start(player_start_r),
    .i_pause(player_pause_r),
    .i_stop(player_stop_r),
    .i_stop_address(o_rec_stop_address_r),
    .o_address(o_player_address),
    .o_done(player_done)
);

player player0(
    .i_rst(i_rst),
    .i_bclk(i_bclk),
    .i_daclrck(i_daclrck),
    .i_en(o_en),
    .i_dac_data(i_aud_data_r),
    .o_aud_dacdat(o_aud_data)
);

// state
always_comb begin
    case (state_r)
        S_IDLE: state_w = i2c_done_r ? S_NORMAL : S_IDLE;
        S_NORMAL: begin
            if(rec_start_r) state_w = S_RECORD;
            else if(player_start_r) state_w = S_PLAY;
            else state_w = S_NORMAL;
        end
        S_RECORD: begin
            if(rec_done_r) state_w = S_NORMAL;
            else state_w = S_RECORD;
        end
        S_PLAY: begin
            if(player_done_r) state_w = S_NORMAL;
            else state_w = S_PLAY;
        end
        default: state_w = state_r;
    endcase
end

// i2c
always_comb begin
    i2c_done_w = (state_r == S_IDLE) ? i2c_done : 1'b0;
end

// ps2
always_comb begin
    if(state_r == S_NORMAL || state_r == S_RECORD) begin
        if(o_ps2_valid) begin
            o_ps2_data_w = o_ps2_data;
        end
        else begin
            o_ps2_data_w = o_ps2_data_r;
        end
    end
    else begin
        o_ps2_data_w = 0;
    end
    o_ps2_valid_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_ps2_valid : 0;
end

// gen
always_comb begin
    gen_start_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_ps2_valid : 0;
    o_gen_data_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_gen_data : 0;
end

// record
always_comb begin
    rec_start_w = (state_r == S_NORMAL) && !rec_done_r && i_key_0;
    rec_stop_w = (state_r == S_RECORD) && i_key_2;
    rec_done_w = rec_done;
    o_rec_data_w = (state_r == S_RECORD) ? o_rec_data : 0;
    o_rec_stop_address_w = o_rec_stop_address;
end

// SRAM
assign o_SRAM_ADDR = (state_r == S_RECORD) ? o_rec_address : ((state_r == S_PLAY) ? o_player_address : 0);
assign io_SRAM_DQ  = (state_r == S_RECORD) ? o_rec_data : 16'dz; // sram_dq as output
assign data_play   = (state_r == S_PLAY) ? io_SRAM_DQ : 16'd0; // sram_dq as input
assign o_SRAM_WE_N = (state_r == S_RECORD && sample_clk == 1'b0) ? 1'b0 : 1'b1;

assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = (state_r == S_PLAY) ? 1'b0 : 1'b1;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

assign o_time = (state_r == S_RECORD) ? o_rec_address[19:15] : ((state_r == S_PLAY) ? o_player_address[19:15] : 0);

// player_controller
always_comb begin
    player_start_w = (state_r == S_NORMAL || state_r == S_PLAY) && rec_done_r && i_key_0;
    player_pause_w = (state_r == S_PLAY) && i_key_1;
    player_stop_w = (state_r == S_PLAY) && i_key_2;
    player_done_w = (state_r == S_PLAY) ? player_done : 0;
end

// player
always_comb begin
    o_en = ~i_daclrck;
    i_aud_data_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_gen_data_r : ((state_r == S_PLAY) ? data_play : 0);
end

reg i2c_poweron_delay;

always_ff @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        state_r <= S_IDLE;
        i2c_start_r <= 0;
        i2c_done_r <= 0;
        rec_start_r <= 0;
        rec_done_r <= 0;
        player_start_r <= 0;
        player_done_r <= 0;
        o_ps2_data_r <= 0;
        o_ps2_valid_r <= 0;
        gen_start_r <= 0;
        o_gen_data_r <= 0;
        rec_stop_r <= 0;
        o_rec_data_r <= 0;
        o_rec_stop_address_r <= 0;
        player_pause_r <= 0;
        player_stop_r <= 0;
        i_aud_data_r <= 0;
        read_address_r <= 0;

        i2c_poweron_delay <= 1'b0;
    end
    else begin
        state_r <= state_w;

        if (!i2c_poweron_delay) begin
            i2c_poweron_delay <= 1'b1;
            // keep i2c_start_r low on this cycle
            i2c_start_r <= 1'b0;
        end
        else begin
            // after that one-cycle delay, set start unless i2c already finished
            if (!i2c_done_r)
                i2c_start_r <= 1'b1;
            else
                i2c_start_r <= 1'b0;
        end

        i2c_done_r <= i2c_done_w;
        rec_start_r <= rec_start_w;
        rec_done_r <= rec_done_w;
        player_start_r <= player_start_w;
        player_done_r <= player_done_w;
        o_ps2_data_r <= o_ps2_data_w;
        o_ps2_valid_r <= o_ps2_valid_w;
        gen_start_r <= gen_start_w;
        o_gen_data_r <= o_gen_data_w;
        rec_stop_r <= rec_stop_w;
        o_rec_data_r <= o_rec_data_w;
        o_rec_stop_address_r <= o_rec_stop_address_w;
        player_pause_r <= player_pause_w;
        player_stop_r <= player_stop_w;
        i_aud_data_r <= i_aud_data_w;
        read_address_r <= read_address_w;
    end
end
    
endmodule
