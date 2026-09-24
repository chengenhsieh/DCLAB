module AudRecorder (
    input         i_rst_n,
    input         i_clk,
    input         i_lrc,
    input         i_start,
    input         i_stop,
    input         i_data,
    output [19:0] o_address, // 紀錄要填寫的address
    output [15:0] o_data, // 要寫入的data
    output [19:0] o_stop_address,
    output        o_finished // 確認寫完
);

parameter S_IDLE = 0; // 等待start
parameter S_LEFT = 1; // 左聲道 不用做事
parameter S_RIGHT = 2; // 右聲道 開始寫入
parameter S_STOP = 3; // 結束

parameter MAX_ADDR = 20'hfffff;

logic [1:0] state_r, state_w;
logic [4:0] counter_r, counter_w;
logic [15:0] data_r, data_w;
logic [19:0] address_r, address_w;
logic stop_r, stop_w;
logic [19:0] stop_address_r, stop_address_w;

assign o_data = data_r;
assign o_address = address_r;
assign o_finished = (state_r == S_STOP);
assign o_stop_address = stop_address_r;

// state
always_comb begin
    case (state_r)
        S_IDLE: state_w = i_start ? S_LEFT : S_IDLE;
        S_LEFT: begin
            if(stop_r) state_w = S_STOP;
            else if(i_lrc) state_w = S_RIGHT;
            else state_w = S_LEFT;
        end
        S_RIGHT: begin
            if(stop_r) state_w = S_STOP;
            else if(!i_lrc) state_w = S_LEFT;
            else state_w = S_RIGHT;
        end
        S_STOP: state_w = S_STOP;
    endcase
end

// counter
always_comb begin
    case (state_r)
        S_LEFT: counter_w = 0; // 回到左聲道的時候要重新記數
        S_RIGHT: begin
            if(counter_r < 16) counter_w = counter_r + 1; // 總共要收集16 bits的data
            else counter_w = counter_r;
        end
        default: counter_w = counter_r;
    endcase
end

// data
always_comb begin
    case (state_r)
        S_LEFT: data_w = 0; // 回到左聲道的時候要清空資料
        S_RIGHT: begin
            if(counter_r < 16) data_w = {data_r[14:0], i_data}; // 收集到的資料填入LSB
            else data_w = data_r;
        end
        default: data_w = data_r;
    endcase
end

// address
always_comb begin
    case (state_r)
        S_IDLE: address_w = 0; // 剛開始的時候從第0個address開始填入
        S_RIGHT: begin
            if(!i_lrc) address_w = address_r + 1; // 每回到左聲道，代表已經收集了16 bits，準備填入下一個address
            else address_w = address_r;
        end
        default: address_w = address_r;
    endcase
end

// stop
always_comb begin
    case (state_r)
        S_IDLE: stop_w = 0;
        S_LEFT: begin
            if(i_stop) stop_w = 1;
            else stop_w = stop_r;
        end
        S_RIGHT: begin
            if(i_stop || (address_r == MAX_ADDR)) stop_w = 1;
            else stop_w = stop_r;
        end
        S_STOP: stop_w = 1;
    endcase
end

// stop address
always_comb begin
    case (state_r)
        S_IDLE: stop_address_w = 0;
        S_RIGHT: stop_address_w = address_r;
        default: stop_address_w = stop_address_r;
    endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        state_r <= S_IDLE;
        counter_r <= 0;
        data_r <= 0;
        address_r <= 0;
        stop_r <= 0;
        stop_address_r <= 0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        data_r <= data_w;
        address_r <= address_w;
        stop_r <= stop_w;
        stop_address_r <= stop_address_w;
    end
end
    
endmodule