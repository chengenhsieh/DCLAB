module Topnew (
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

    // SDRAM
    output [24:0] qsys_sdram_address,
    output        qsys_sdram_write,
    output [31:0] qsys_sdram_writedata,
    input         qsys_sdram_waitrequest,

    output        qsys_sdram_read,
    input  [31:0] qsys_sdram_readdata,
    input         qsys_sdram_readdatavalid,

    // player
    input i_bclk, // 1.6 MHz
    input i_daclrck, // 50 kHz
    output o_aud_data
);

parameter S_IDLE = 0;
parameter S_NORMAL = 1;
parameter S_RECORD = 2;
parameter S_PLAY = 3;

logic [1:0] state_r, state_w;

// i2c variable
logic i2c_start_r, i2c_start_w;
logic i2c_done, i2c_done_r, i2c_done_w;
logic i2c_oen;

// ps2 variable
logic [7:0] o_ps2_data, o_ps2_data_r, o_ps2_data_w;
logic o_ps2_valid, o_ps2_valid_r, o_ps2_valid_w;

// gen variable
logic gen_start_r, gen_start_w;
logic [15:0] o_gen_data, o_gen_data_r, o_gen_data_w;

// record variable
logic rec_start_r, rec_start_w;
logic rec_done, rec_done_r, rec_done_w;
logic rec_pause_r, rec_pause_w;
logic rec_stop_r, rec_stop_w;
logic [24:0] o_rec_address;
logic [31:0] o_rec_data, o_rec_data_r, o_rec_data_w;
logic o_wr_en;
logic [24:0] o_rec_stop_address, o_rec_stop_address_r, o_rec_stop_address_w;

// player variable
logic player_start_r, player_start_w;
logic player_done, player_done_r, player_done_w;
logic player_pause_r, player_pause_w;
logic player_stop_r, player_stop_w;
logic [15:0] o_player_data, o_player_data_r, o_player_data_w;
logic [31:0] i_player_data_r, i_player_data_w;
logic [24:0] o_player_address;
logic o_en;
logic [15:0] i_aud_data_r, i_aud_data_w;

logic [24:0] read_address_r, read_address_w;
logic read_num_r, read_num_w;

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
logic [11:0] o_key_vector, o_key_vector_r, o_key_vector_w;
top gen0(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(gen_start_r),
    .i_ps2_data(o_ps2_data_r),
    .o_audio_sample(o_gen_data),
    .o_key_vector(o_key_vector)
);

recorder rec(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(rec_start_r),
    .i_data(o_gen_data_r),
    .i_pause(rec_pause_r),
    .i_stop(rec_stop_r),
    .o_address(o_rec_address),
    .o_data(o_rec_data),
    .o_wr_en(o_wr_en),
    .o_stop_address(o_rec_stop_address),
    .o_finish(rec_done)
);

player_controller controll(
    .i_rst(i_rst),
    .i_clk(sample_clk),
    .i_start(player_start_r),
    .i_pause(player_pause_r),
    .i_stop(player_stop_r),
    .i_data(i_player_data_r),
    .i_stop_address(o_rec_stop_address_r),
    .o_address(o_player_address),
    .o_data(o_player_data),
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
    endcase
end

// i2c
always_comb begin
    i2c_start_w = (state_r == S_IDLE) && !i2c_done_r;
    i2c_done_w = (state_r == S_IDLE) ? i2c_done : 1'b0;
end

// ps2
always_comb begin
    o_ps2_data_w = ((state_r == S_NORMAL || state_r == S_RECORD) && o_ps2_valid) ? o_ps2_data : 0;
    o_ps2_valid_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_ps2_valid : 0;
end

// gen
always_comb begin
    gen_start_w = (state_r == S_NORMAL || state_r == S_RECORD) ? |(o_key_vector_r) : 0;
    o_gen_data_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_gen_data : 0;
    o_key_vector_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_key_vector : 0;
end

// record
always_comb begin
    rec_start_w = (state_r == S_NORMAL) && i_key_0;
    rec_pause_w = (state_r == S_RECORD) && i_key_1;
    rec_stop_w = (state_r == S_RECORD) && i_key_2;
    rec_done_w = (state_r == S_RECORD) ? rec_done : 1'b0;
    o_rec_data_w = (state_r == S_RECORD) ? o_rec_data : 0;
    o_rec_stop_address_w = (state_r == S_RECORD) ? o_rec_stop_address : 0;
end

always_comb begin
    if(state_r == S_PLAY) begin
        if(read_num_r) read_address_w = read_address_r + 1;
        else read_address_w = read_address_r;
        read_num_w = !read_num_r;
    end
    else begin
        read_address_w = 0;
        read_num_w = 0;
    end
end

// SDRAM
assign qsys_sdram_address = (state_r == S_RECORD) ? o_rec_address : ((state_r == S_PLAY) ? read_address_r : 0);
assign qsys_sdram_write = o_wr_en && !qsys_sdram_waitrequest && (state_r == S_RECORD);
assign qsys_sdram_writedata = o_rec_data_r;
assign qsys_sdram_read = (state_r == S_PLAY) && !qsys_sdram_waitrequest;

// player_controller
always_comb begin
    player_start_w = (state_r == S_NORMAL) && rec_done_r && i_key_2;
    player_pause_w = (state_r == S_PLAY) && i_key_1;
    player_stop_w = (state_r == S_PLAY) && i_key_0;
    player_done_w = (state_r == S_PLAY) ? player_done : 0;
    o_player_data_w = o_player_data;
    i_player_data_w = (state_r == S_PLAY && qsys_sdram_readdatavalid) ? qsys_sdram_readdata : i_player_data_r;
end

// player
always_comb begin
    o_en = ~i_daclrck;
    i_aud_data_w = (state_r == S_NORMAL || state_r == S_RECORD) ? o_gen_data_r : ((state_r == S_PLAY) ? o_player_data_r : 0);
end

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
        rec_pause_r <= 0;
        rec_stop_r <= 0;
        o_rec_data_r <= 0;
        o_rec_stop_address_r <= 0;
        player_pause_r <= 0;
        player_stop_r <= 0;
        o_player_data_r <= 0;
        i_player_data_r <= 0;
        i_aud_data_r <= 0;
        read_address_r <= 0;
        read_num_r <= 0;
        o_key_vector_r <= 0;
    end
    else begin
        state_r <= state_w;
        i2c_start_r <= i2c_start_w;
        i2c_done_r <= i2c_done_w;
        rec_start_r <= rec_start_w;
        rec_done_r <= rec_done_w;
        player_start_r <= player_start_w;
        player_done_r <= player_done_w;
        o_ps2_data_r <= o_ps2_data_w;
        o_ps2_valid_r <= o_ps2_valid_w;
        gen_start_r <= gen_start_w;
        o_gen_data_r <= o_gen_data_w;
        rec_pause_r <= rec_pause_w;
        rec_stop_r <= rec_stop_w;
        o_rec_data_r <= o_rec_data_w;
        o_rec_stop_address_r <= o_rec_stop_address_w;
        player_pause_r <= player_pause_w;
        player_stop_r <= player_stop_w;
        o_player_data_r <= o_player_data_w;
        i_player_data_r <= i_player_data_w;
        i_aud_data_r <= i_aud_data_w;
        read_address_r <= read_address_w;
        read_num_r <= read_num_w;
        o_key_vector_r <= o_key_vector_w;
    end
end
    
endmodule