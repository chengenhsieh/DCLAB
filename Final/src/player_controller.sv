module player_controller (
    input i_clk,
    input i_rst,
    input sample_clk, // 50 kHz
    input i_start,
    input i_pause,
    input i_stop,
    input [19:0] i_stop_address,
    output [19:0] o_address,
    output o_done
);

parameter S_IDLE = 0;
parameter S_PLAY = 1;
parameter S_PAUSE = 2;
parameter S_STOP = 3;

logic [1:0] state_r, state_w;
logic stop_r, stop_w;
logic [19:0] address_r, address_w;

assign o_address = address_r;
assign o_done = (state_r == S_STOP);

// state
always_comb begin
    case (state_r)
        S_IDLE: state_w = i_start ? S_PLAY : S_IDLE;
        S_PLAY: begin
            if(stop_r) state_w = S_STOP;
            else if(i_pause) state_w = S_PAUSE;
            else state_w = S_PLAY;
        end
        S_PAUSE: begin
            if(i_start) state_w = S_PLAY;
            else if(stop_r) state_w = S_STOP;
            else state_w = S_PAUSE;
        end
        S_STOP: state_w = S_STOP;
    endcase
end

// stop
assign stop_w = (address_r >= i_stop_address) || i_stop;

// address
always_comb begin
    case (state_r)
        S_IDLE: address_w = 0;
        S_PLAY: begin
            address_w = address_r + 1;
        end
        S_PAUSE: address_w = address_r;
        S_STOP: address_w = address_r;
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        state_r <= S_IDLE;
        stop_r <= 0;
    end
    else begin
        state_r <= state_w;
        stop_r <= stop_w;
    end
end

always_ff @(posedge sample_clk or posedge i_rst) begin
    if(i_rst) begin
        address_r <= 0;
    end
    else begin
        address_r <= address_w;
    end
end
    
endmodule