module AudDSP (
    input i_rst,
    input i_clk,
    input i_start,
    input i_pause,
    input [2:0] i_speed,
    input i_is_slow,
    input i_slow_mode,
    input i_daclrck,
    input signed [15:0] i_sram_data,
    input [19:0] i_sram_stop_addr,
    output signed [15:0] o_dac_data,
    output o_en,
    output o_is_pause,
    output [19:0] o_sram_addr
);
    localparam S_IDLE     = 0;
    localparam S_PAUSE    = 1;
    localparam S_GETDATA  = 2;
    localparam S_SENDDATA = 3;
    
    reg [2:0] state_r, state_w;
    reg [3:0] slow_counter_r, slow_counter_w;
    reg [1:0] get_data_counter_r, get_data_counter_w;

    reg is_pause_r, is_pause_w;

    reg [19:0] addr_r, addr_w;
    reg signed [15:0] data_curr_r, data_curr_w;
    reg signed [15:0] data_next_r, data_next_w;

    reg [15:0] o_data_r, o_data_w;

    assign o_dac_data = o_data_r;
    assign o_en = !i_daclrck;
    assign o_is_pause = is_pause_r;
    assign o_sram_addr = addr_r;

    always @(*) begin
        state_w = state_r;
        case(state_r)
            S_IDLE: begin
                if (i_start)        state_w = S_PAUSE;
                else                state_w = S_IDLE;
            end
            S_PAUSE: begin
                if (is_pause_r)     state_w = S_PAUSE;
                else                state_w = S_GETDATA;
            end
            S_GETDATA: begin
                if (is_pause_r)     state_w = S_PAUSE;
                else begin
                    if (!i_daclrck) state_w = S_SENDDATA;
                    else            state_w = S_GETDATA;
                end
            end
            S_SENDDATA: begin
                if (is_pause_r)     state_w = S_PAUSE;
                else begin
                    if (!i_daclrck) state_w = S_SENDDATA;
                    else            state_w = S_GETDATA;
                end
            end
        endcase
    end

    always @(*) begin
        slow_counter_w = slow_counter_r;
        case(state_r)
            S_IDLE:     slow_counter_w = 0;
            S_PAUSE:    slow_counter_w = 0;
            S_SENDDATA: begin
                if(i_is_slow && !is_pause_r && i_daclrck) begin
                    if(slow_counter_r == i_speed) slow_counter_w = 0;
                    else                          slow_counter_w = slow_counter_r + 1;
                end
            end
        endcase
    end

    always @(*) begin
        get_data_counter_w = get_data_counter_r;
        case(state_r)
            S_IDLE:     get_data_counter_w = 0;
            S_PAUSE:    get_data_counter_w = 0;
            S_GETDATA:  if(get_data_counter_r < 3) get_data_counter_w = get_data_counter_r + 1;
            S_SENDDATA: get_data_counter_w = 0;
        endcase
    end

    always @(*) begin
        is_pause_w = is_pause_r;
        case(state_r)
            S_IDLE:     is_pause_w = 1;
            S_PAUSE:    if(i_pause) is_pause_w = 0;
            S_GETDATA:  if(i_pause) is_pause_w = 1;
            S_SENDDATA: if(i_pause) is_pause_w = 1;
        endcase
    end

    reg [20:0] temp_addr;
    always @(*) begin
        addr_w = addr_r;
        temp_addr = addr_r;
        case(state_r)
            S_IDLE: temp_addr = 0;
            S_GETDATA: begin
                if(get_data_counter_r == 0) begin
                    if(i_is_slow) begin
                        if(slow_counter_r == 0) temp_addr = addr_r + 1;
                    end
                    else begin
                        temp_addr = addr_r + i_speed + 1;
                    end
                end
            end
        endcase
        if(temp_addr > i_sram_stop_addr) addr_w = 0;
        else                             addr_w = temp_addr;
    end

    always @(*) begin
        data_curr_w = data_curr_r;
        data_next_w = data_next_r;
        case(state_r)
            S_IDLE: data_next_w = 0;
            S_PAUSE: data_next_w = i_sram_data;
            S_GETDATA: begin
                if(get_data_counter_r == 2) begin
                    if(i_is_slow) begin
                        if(slow_counter_r == 0) begin
                            data_curr_w = data_next_r;
                            data_next_w = i_sram_data;
                        end
                    end
                    else begin
                        data_curr_w = data_next_r;
                        data_next_w = i_sram_data;
                    end
                end
            end
        endcase
    end

    reg signed [16:0] diff;
    reg signed [20:0] diff_times_slow_counter;
    reg signed [20:0] diff_times_slow_counter_div_speed;
    always @(*) begin
        o_data_w = o_data_r;
        diff = 0;
        diff_times_slow_counter = 0;
        diff_times_slow_counter_div_speed = 0;
        case(state_r)
            S_IDLE: o_data_w = 0;
            S_GETDATA: begin
                if(get_data_counter_r == 3) begin
                    if(i_is_slow && i_slow_mode) begin  // slow mode : linear
                        diff = $signed(data_next_r) - $signed(data_curr_r);
                        diff_times_slow_counter = $signed(diff) * $signed({1'b0, slow_counter_r});
                        diff_times_slow_counter_div_speed = $signed($signed(diff_times_slow_counter) / $signed({1'b0, i_speed + 1}));
                        o_data_w = $signed($signed(data_curr_r) + $signed(diff_times_slow_counter_div_speed));
                    end
                    else begin                          // slow mode : constant & fast mode
                        o_data_w = data_curr_r;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            state_r <= S_IDLE;
            slow_counter_r <= 0;
            get_data_counter_r <= 0;
            is_pause_r <= 1;
            addr_r <= 0;
            data_curr_r <= 0;
            data_next_r <= 0;
            o_data_r <= 0;
        end
        else begin
            state_r <= state_w;
            slow_counter_r <= slow_counter_w;
            get_data_counter_r <= get_data_counter_w;
            is_pause_r <= is_pause_w;
            addr_r <= addr_w;
            data_curr_r <= data_curr_w;
            data_next_r <= data_next_w;
            o_data_r <= o_data_w;
        end
    end
endmodule