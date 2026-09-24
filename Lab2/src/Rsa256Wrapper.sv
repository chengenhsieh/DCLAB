module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address, // 選擇暫存器 RX=0 TX=4 STATUS=8
    output        avm_read, // 1代表要讀
    input  [31:0] avm_readdata, // 讀入的data 只有[7:0]有用
    output        avm_write, // 1代表要寫
    output [31:0] avm_writedata, // 要寫出去的data
    input         avm_waitrequest // 1代表正在運算 無法讀寫
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
localparam S_QUERY_RX = 0; // 確認可讀
localparam S_READ = 1; // 讀n, d, enc
localparam S_CALCULATE = 2; // 計算
localparam S_QUERY_TX = 3; // 確認可寫
localparam S_WRITE = 4; // 寫dec

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w; // n: N, d: 私鑰, enc: ciphertext, dec: plaintext
logic [2:0] state_r, state_w; // state now and next
logic [6:0] bytes_counter_r, bytes_counter_w; // 計數器 確認還有多少byte要送
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w; // 控制core啟動
logic rsa_finished; // core告知解完
logic [255:0] rsa_dec; // core解密結果

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

// core
Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

// select register
task automatic StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task automatic StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

// state transition
always_comb begin
    // TODO
    case (state_r)
        // 確認watirequest跟rx_ok_bit，可以的話開始讀
        S_QUERY_RX: begin
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) state_w = S_READ;
            else state_w = S_QUERY_RX;
        end 
        // waitrequest = 1則維持，否則讀n 32bytes, d 32bytes, enc 32bytes，讀完後開始運算
        S_READ: begin
            if(avm_waitrequest) state_w = S_READ;
            else if(bytes_counter_r == 95) state_w = S_CALCULATE;
            else state_w = S_QUERY_RX;
        end
        // 等待core回傳運算完畢
        S_CALCULATE: begin
            if(rsa_finished) state_w = S_QUERY_TX;
            else state_w = S_CALCULATE;
        end
        // 確認waitrequest跟tx_ok_bit，可以的話開始寫
        S_QUERY_TX: begin
            if(!avm_waitrequest && avm_readdata[TX_OK_BIT]) state_w = S_WRITE;
            else state_w = S_QUERY_TX;
        end
        // waitrequest = 1則維持，否則寫dec 31bytes，寫完後回到原始狀態
        S_WRITE: begin
            if(avm_waitrequest) state_w = S_WRITE;
            else if(bytes_counter_r == 30) state_w = S_QUERY_RX;
            else state_w = S_QUERY_TX;
        end

    endcase
end

// bytes counter
always_comb begin

    case (state_r)
        // 每讀一個byte counter += 1，讀完後歸零
        S_READ: begin
            if(avm_waitrequest) bytes_counter_w = bytes_counter_r;
            else if(bytes_counter_r == 95) bytes_counter_w = 0;
            else bytes_counter_w = bytes_counter_r + 1;
        end
        // 每寫一個byte counter += 1，寫完後回到64，因不必再讀入32bytes n及32bytes d
        S_WRITE: begin
            if(avm_waitrequest) bytes_counter_w = bytes_counter_r;
            else if(bytes_counter_r == 30) bytes_counter_w = 64;
            else bytes_counter_w = bytes_counter_r + 1;
        end

        default: bytes_counter_w = bytes_counter_r;

    endcase

end

// core inputs
always_comb begin

    case (state_r)
        // 每次讀入8bits，讀入的資料放在最低位
        S_READ: begin
            if(avm_waitrequest) begin
                n_w = n_r;
                d_w = d_r;
                enc_w = enc_r;
            end
            else if(bytes_counter_r < 32) begin
                n_w[255:0] = {n_r[247:0], avm_readdata[7:0]};
                d_w = d_r;
                enc_w = enc_r;
            end
            else if(bytes_counter_r < 64) begin
                n_w = n_r;
                d_w[255:0] = {d_r[247:0], avm_readdata[7:0]};
                enc_w = enc_r;
            end
            else begin
                n_w = n_r;
                d_w = d_r;
                enc_w[255:0] = {enc_r[247:0], avm_readdata[7:0]};
            end
        end

        default: begin
            n_w = n_r;
            d_w = d_r;
            enc_w = enc_r;
        end

    endcase

end

//core control
always_comb begin

    case (state_r)
        // 讀完資料時，控制core開始運算
        S_READ: begin
            if(avm_waitrequest) rsa_start_w = 0;
            else if(bytes_counter_r == 95) rsa_start_w = 1;
            else rsa_start_w = 0;
        end

        default: rsa_start_w = 0;

    endcase

end

//core output
always_comb begin

    case (state_r)
        // dec_w接受運算結果
        S_CALCULATE: dec_w = rsa_dec;
        // 每次寫出8bits
        S_WRITE: begin
            if(avm_waitrequest) dec_w = dec_r;
            else dec_w[255:0] = {dec_r[247:0], 8'b0};
        end

        default: dec_w = dec_r;

    endcase

end

// avm
always_comb begin
    
    StartRead(STATUS_BASE);

    case (state_r)
        // rx_ok_bit還未確定前，持續在base+8+確認，確定後轉換至base+0開始讀
        S_QUERY_RX: begin
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) StartRead(RX_BASE);
            else StartRead(STATUS_BASE);
        end
        // waitrequest = 0會回到query_rx繼續確認，否則繼續讀
        S_READ: begin
            if(avm_waitrequest) StartRead(RX_BASE);
            else StartRead(STATUS_BASE);
        end

        S_CALCULATE: StartRead(STATUS_BASE);
        // tx_ok_bit還未確定前，持續在base+8確認，確定後轉換至base+4開始寫
        S_QUERY_TX: begin
            if(!avm_waitrequest && avm_readdata[TX_OK_BIT]) StartWrite(TX_BASE);
            else StartRead(STATUS_BASE);
        end
        // waitrequest = 0會回到query_tx繼續確認，否則繼續寫
        S_WRITE: begin
            if(avm_waitrequest) StartWrite(TX_BASE);
            else StartRead(STATUS_BASE);
        end

    endcase

end

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_QUERY_RX;
        bytes_counter_r <= 0;
        rsa_start_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
    end
end

endmodule
