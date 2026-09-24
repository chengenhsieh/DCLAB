module recorder (
    input         i_clk, // 50M clk
    input         sample_clk, // 50k sample clk
    input         i_rst,
    input         i_start, // 開始錄音
    input  [15:0] i_data, // 輸入的資料
    input         i_stop, // 結束
    output [19:0] o_address, // 要填寫的address
    output [15:0] o_data, // 輸出的資料
    output [19:0] o_stop_address, // 最後儲存的address
    output        o_finish // 是否結束
);

parameter S_IDLE = 0;
parameter S_RECORD = 1;
parameter S_STOP = 2;

parameter MAX_ADDR = 20'hfffff;

logic [1:0] state_r, state_w;
logic [15:0] data_r, data_w;
logic stop_r, stop_w;
logic [19:0] address_r, address_w;
logic [19:0] stop_address_r, stop_address_w;

assign o_address = address_r;
assign o_data = data_r;
assign o_stop_address = stop_address_r;
assign o_finish = (state_r == S_STOP);
assign o_wr_en = (state_r == S_RECORD);

// state
always_comb begin
    case (state_r)
        S_IDLE: state_w = i_start ? S_RECORD : S_IDLE;
        S_RECORD: begin
            if(stop_r) state_w = S_STOP;
            else state_w = S_RECORD;
        end
        S_STOP: state_w = S_STOP;
    endcase
end

// data
always_comb begin
    case (state_r)
        S_IDLE: data_w = 0;
        S_RECORD: begin
            data_w = i_data;
        end
        S_STOP: data_w = data_r;
    endcase
end

// stop
always_comb begin
    case (state_r)
        S_IDLE: stop_w = 0;
        S_RECORD: stop_w = i_stop || (address_r == MAX_ADDR);
        S_STOP: stop_w = 1;
    endcase
end

// address
always_comb begin
    case (state_r)
        S_IDLE: address_w = 0;
        S_RECORD: begin
            address_w = address_r + 1;
        end
        S_STOP: address_w = address_r;
    endcase
end

// stop_address
always_comb begin
    case (state_r)
        S_IDLE: stop_address_w = 0;
        S_RECORD: stop_address_w = address_r;
        S_STOP: stop_address_w = stop_address_r;
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
        data_r <= 0;
        address_r <= 0;
        stop_address_r <= 0;
    end
    else begin
        data_r <= data_w;
        address_r <= address_w;
        stop_address_r <= stop_address_w;
    end
end
    
endmodule