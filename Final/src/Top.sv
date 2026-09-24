module Top (
    input i_clk, // 50 MHz
    input i_rst, // map to key3
    input i_key_0, // start to record
    input i_key_1, // record/audio pause
    input i_key_2, // record stop / play audio (audio stop -> reset)

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

// original: S_IDLE
// press rst -> i2c -> S_NORMAL
// press key0 -> S_RECORD (still playing)

parameter S_IDLE = 0;
parameter S_NORMAL = 1;
parameter S_RECORD = 2;
parameter S_PLAY = 3;

logic [1:0] state_r, state_w;

logic i2c_oen, i2c_done, i2c_delay;
logic i2c_start_r, i2c_start_w;
logic i2c_done_r, i2c_done_w;

logic [7:0] o_ps2_data, o_ps2_data_r, o_ps2_data_w;
logic o_ps2_valid, o_ps2_valid_r, o_ps2_valid_w;

logic [15:0] sample, sample_r, sample_w;

logic rec_start_r, rec_start_w;

logic [24:0] record_address, stop_address;
logic [31:0] record_data;
logic record_done, wr_en;

logic player_start_r, player_start_w;
logic [31:0] player_data; // TODO
logic [24:0] play_address; // TODO
logic [15:0] voice_data; // TODO

logic o_en;
logic [15:0] audio_data;

logic sdram_read_r, sdram_read_w;
logic [24:0] sdram_addr_r, sdram_addr_w;
logic [31:0] sdram_data_r;
logic sdram_valid_r;

assign o_en = ~i_daclrck;

always_comb begin
    case (state_r)
        S_IDLE: audio_data = 0;
        S_NORMAL: audio_data = sample_r;
        S_RECORD: audio_data = sample_r;
        S_PLAY: audio_data = voice_data; 
    endcase
end

// SDRAM
assign qsys_sdram_address = (state_r == S_RECORD) ? record_address : ((state_r == S_PLAY) ? play_address : 0);
assign qsys_sdram_writedata = record_data;
assign qsys_sdram_write = wr_en && (state_r == S_RECORD) && !qsys_sdram_waitrequest;
assign qsys_sdram_read = (state_r == S_PLAY) && sdram_read_r && !qsys_sdram_waitrequest;

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

gen gen1(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(o_ps2_valid_r),
    .i_ps2_data(o_ps2_data_r),
    .o_audio_sample(sample)
);

recorder record(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(rec_start_r),
    .i_data(sample_r),
    .i_pause(i_key_1),
    .i_stop(i_key_2),
    .o_address(record_address),
    .o_data(record_data),
    .o_stop_address(stop_address),
    .o_wr_en(wr_en),
    .o_finish(record_done)
);

player_controller controll(
    .i_clk(sample_clk),
    .i_rst(i_rst),
    .i_start(player_start_r),
    .i_pause(i_key_1),
    .i_data(sdram_data_r),
    // player_data 尚未解決，須從SDRAM讀取資料
    .o_address(play_address),
    .i_stop_address(stop_address),
    .o_data(voice_data)
);

player player0(
    .i_rst(i_rst),
    .i_bclk(i_bclk),
    .i_daclrck(i_daclrck),
    .i_en(o_en),
    .i_dac_data(audio_data),
    .o_aud_dacdat(o_aud_data)
);

// state
always_comb begin
    case (state_r)
        S_IDLE: state_w = i2c_done_r ? S_NORMAL : S_IDLE;
        S_NORMAL: begin
            if(i_key_0) state_w = S_RECORD;
            else if(i_key_2) state_w = S_PLAY;
            else state_w = S_NORMAL;
        end
        S_RECORD: begin
            if(i_key_2) state_w = S_NORMAL;
            else state_w = S_RECORD;
        end
        S_PLAY: begin
            if(i_key_2) state_w = S_NORMAL;
            else state_w = S_PLAY;
        end
    endcase
end

// start
always_comb begin
    if(i2c_done_r) i2c_start_w = 1'b0;
    else i2c_start_w = i2c_start_r;
    if(i2c_done_r && (state_r == S_RECORD) && i_key_0) rec_start_w = 1'b1;
    else rec_start_w = rec_start_r;
    if(i_key_2 && (state_r == S_PLAY)) player_start_w = 1'b1;
    else player_start_w = player_start_r;
end

// done
always_comb begin
    if(i2c_done) i2c_done_w = 1'b1;
    else i2c_done_w = i2c_done_r;
end

// ps2
always_comb begin
    o_ps2_data_w = o_ps2_data;
    o_ps2_valid_w = o_ps2_valid;
    sample_w = sample;
end

// sdram read
always_comb begin
    sdram_read_w = 1'b0;
    sdram_addr_w = sdram_addr_r;
    if(state_r == S_PLAY) begin
        if(!qsys_sdram_waitrequest) begin
            sdram_read_w = 1'b1;
            sdram_addr_w = play_address;
        end
    end
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        state_r <= S_IDLE;
        i2c_start_r <= 1'b0;
        i2c_done_r <= 1'b0;
        i2c_delay <= 1'b0;
        o_ps2_data_r <= 8'h00;
        o_ps2_valid_r <= 1'b0;
        sample_r <= 16'h0000;
        rec_start_r <= 0;
        player_start_r <= 0;
    end
    else begin
        state_r <= state_w;
        i2c_start_r <= i2c_start_w;
        if(!i2c_delay) begin
            i2c_delay <= 1'b1;
            i2c_start_r <= 1'b0;
        end
        else begin
            if(!i2c_done_r) i2c_start_r <= 1'b1;
            else i2c_start_r <= 1'b0;
        end
        i2c_done_r <= i2c_done_w;
        o_ps2_data_r <= o_ps2_data_w;
        o_ps2_valid_r <= o_ps2_valid_w;
        sample_r <= sample_w;
        rec_start_r <= rec_start_w;
        player_start_r <= player_start_w;
    end
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        sdram_addr_r <= 0;
        sdram_read_r <= 0;
        sdram_data_r <= 0;
        sdram_valid_r <= 0;
    end
    else begin
        sdram_read_r <= sdram_read_w;
        sdram_addr_r <= sdram_addr_w;
        if(qsys_sdram_readdatavalid) begin
            sdram_data_r <= qsys_sdram_readdata;
            sdram_valid_r <= 1'b1;
        end
        else begin
            sdram_valid_r <= 1'b0;
        end
    end
end

endmodule