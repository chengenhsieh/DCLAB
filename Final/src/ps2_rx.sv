// 此 module 功能為將輸入的 11 bits，擷取成有效的 8 bits 輸出
module ps2_rx (
    input        i_clk, // i_clk
    input        i_rst,
    input        ps2_clk, // ps2 送出的 clk，data 會在 1 -> 0 的時候傳送
    input        ps2_data, // ps2 送出的 data
    output [7:0] o_data, // 擷取後的 data
    output       o_valid // 確認是否擷取完畢，維持1個50 kHZ週期
);

parameter S_WAIT = 0;
parameter S_READ = 1;
parameter S_DONE = 2;

logic [1:0] state_r, state_w;
logic ps2_clk_1, ps2_clk_0;
logic [3:0] counter_r, counter_w;
logic [10:0] data_r, data_w;
logic [9:0] o_counter_r, o_counter_w;

logic ps2_fall; // 偵測 ps2_clk 負緣

assign ps2_fall = (ps2_clk_1 == 1) && (ps2_clk_0 == 0);
assign o_valid = (state_r == S_DONE);
assign o_data = data_r[8:1];

// state
always_comb begin
    case (state_r)
        S_WAIT: begin
            if(ps2_fall && ps2_data == 0) state_w = S_READ;
            else state_w = S_WAIT;
        end
        S_READ: begin
            if(counter_r == 10) state_w = S_DONE;
            else state_w = S_READ;
        end
        S_DONE: begin
            if(o_counter_r == 10'b1111101000) state_w = S_WAIT;
            else state_w = S_DONE;
        end
    endcase
end

// o_counter
always_comb begin
    if(state_r == S_DONE) begin
        o_counter_w = o_counter_r + 1;
    end
    else o_counter_w = 0;
end

// counter
always_comb begin
    case (state_r)
        S_WAIT: counter_w = 0;
        S_READ: begin
            if(ps2_fall) counter_w = counter_r + 1;
            else counter_w = counter_r;
        end
        S_DONE: counter_w = counter_r;
    endcase
end

// data
always_comb begin
    case (state_r)
        S_WAIT: data_w = 0;
        S_READ: begin
            if(ps2_fall) data_w = {ps2_data, data_r[10:1]};
            else data_w = data_r;
        end
        S_DONE: data_w = data_r;
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if(i_rst) begin
        state_r <= S_WAIT;
        ps2_clk_1 <= 1;
        ps2_clk_0 <= 1;
        counter_r <= 0;
        data_r <= 0;
        o_counter_r <= 0;
    end
    else begin
        state_r <= state_w;
        ps2_clk_0 <= ps2_clk;
        ps2_clk_1 <= ps2_clk_0;
        counter_r <= counter_w;
        data_r <= data_w;
        o_counter_r <= o_counter_w;
    end
end
    
endmodule