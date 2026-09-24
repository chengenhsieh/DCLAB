module event_sync (
    input  wire        clk_fast,    // e.g. 50 MHz
    input  wire        clk_slow,    // e.g. 50 kHz
    input  wire        rst,

    // fast-side inputs
    input  wire        fast_valid,
    input  wire [7:0]  fast_data,

    // slow-side outputs
    output reg         slow_pulse,
    output reg  [7:0]  slow_data
);

    // ===========================================================
    // Fast domain
    // ===========================================================
    reg req_toggle_f;
    reg pending_f;
    reg [7:0] data_f;

    // sync ack back into fast domain
    reg ack_s_r;
    reg ack_f1, ack_f2;
    reg ack_f2_prev;

    always @(posedge clk_fast or posedge rst) begin
        if (rst) begin
            req_toggle_f <= 0;
            pending_f <= 0;
            data_f <= 8'd0;

            ack_f1 <= 0;
            ack_f2 <= 0;
            ack_f2_prev <= 0;
        end else begin
            // sync ack back from slow
            ack_f1 <= ack_s_r;
            ack_f2 <= ack_f1;

            // detect ack toggle
            if (ack_f2 != ack_f2_prev) begin
                pending_f <= 0;
            end
            ack_f2_prev <= ack_f2;

            // handle new fast_valid
            if (fast_valid && !pending_f) begin
                data_f <= fast_data;
                req_toggle_f <= ~req_toggle_f;
                pending_f <= 1;
            end
        end
    end

    // ===========================================================
    // Cross from fast → slow
    // ===========================================================
    reg req_f1_s, req_f2_s;
    reg req_f2_s_prev;

    always @(posedge clk_slow or posedge rst) begin
        if (rst) begin
            req_f1_s <= 0;
            req_f2_s <= 0;
            req_f2_s_prev <= 0;
        end else begin
            req_f1_s <= req_toggle_f;
            req_f2_s <= req_f1_s;
            req_f2_s_prev <= req_f2_s;
        end
    end

    // ===========================================================
    // Synchronize data_f into slow domain
    // ===========================================================
    reg [7:0] data_s1, data_s2;

    always @(posedge clk_slow or posedge rst) begin
        if (rst) begin
            data_s1 <= 0;
            data_s2 <= 0;
        end else begin
            data_s1 <= data_f;
            data_s2 <= data_s1;
        end
    end

    // ===========================================================
    // Slow domain: detect request edge → produce slow_pulse & data
    // ===========================================================
    reg ack_toggle_s;       // local toggle to ack back

    always @(posedge clk_slow or posedge rst) begin
        if (rst) begin
            slow_pulse <= 0;
            slow_data  <= 0;
            ack_toggle_s <= 0;
        end else begin
            slow_pulse <= 0; // default

            // detect req toggle
            if (req_f2_s != req_f2_s_prev) begin
                slow_pulse <= 1'b1;
                slow_data  <= data_s2;
                ack_toggle_s <= ~ack_toggle_s;
            end
        end
    end

    // ===========================================================
    // send ack_toggle_s back into fast domain
    // ===========================================================
    always @(posedge clk_slow or posedge rst) begin
        if (rst)
            ack_s_r <= 0;
        else
            ack_s_r <= ack_toggle_s;
    end

endmodule
