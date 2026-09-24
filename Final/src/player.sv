module player (
    input         i_rst, // reset
    input         i_bclk, // bit clk 1.6 MHz
    input         i_daclrck, // dac clk 50 kHz
    input         i_en, // whether to output
    input  [15:0] i_dac_data, // input data
    output        o_aud_dacdat // output data
);
    
parameter S_IDLE = 0;
parameter S_TRAN = 1;
parameter S_WAIT = 2;

logic [1:0] state_r, state_w;
logic [15:0] o_aud_dacdat_r, o_aud_dacdat_w;
logic [4:0] counter_r, counter_w;

assign o_aud_dacdat = o_aud_dacdat_r[15];

// state
always_comb begin
    case (state_r)
        S_IDLE: begin
            if(i_en && !i_daclrck) state_w = S_TRAN;
            else state_w = S_IDLE;
        end
        S_TRAN: begin
            if(counter_r == 15) state_w = S_WAIT;
            else state_w = S_TRAN;
        end
        S_WAIT: begin
            if(i_daclrck) state_w = S_IDLE;
            else state_w = S_WAIT;
        end
    endcase
end

// o_aud_dacdat
always_comb begin
    case (state_r)
        S_IDLE: begin
            if(i_en && !i_daclrck) o_aud_dacdat_w = i_dac_data;
            else o_aud_dacdat_w = o_aud_dacdat_r;
        end
        S_TRAN: o_aud_dacdat_w = {o_aud_dacdat_r[14:0], 1'b0};
        S_WAIT: o_aud_dacdat_w = o_aud_dacdat_r;
    endcase
end

// counter
always_comb begin
    case (state_r)
        S_IDLE: counter_w = 0;
        S_TRAN: counter_w = counter_r + 1;
        S_WAIT: counter_w = counter_r;
    endcase
end

always_ff @(posedge i_bclk or posedge i_rst) begin
    if(i_rst) begin
        state_r <= S_IDLE;
        o_aud_dacdat_r <= 0;
        counter_r <= 0;
    end
    else begin
        state_r <= state_w;
        o_aud_dacdat_r <= o_aud_dacdat_w;
        counter_r <= counter_w;
    end
end

endmodule