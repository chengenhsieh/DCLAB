### 輸入與輸出

module AudRecorder (
    input         i_rst_n, // reset
    input         i_clk, // BCLK
    input         i_lrc, // LRCK
    input         i_start, // 開始
    input         i_stop, // 停止
    input         i_data, // 輸入的data
    output [19:0] o_address, // 要填入的address
    output [15:0] o_data, // 要填入的data
    output        o_finished // 回傳是否結束
);

### 改動

1. 刪除 i_pause (感覺輸入的時候暫停沒什麼意義)
2. 新增 o_finished (確認是否輸入結束)