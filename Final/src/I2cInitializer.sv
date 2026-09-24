module I2cInitializer (
    input i_clk,
    input i_rst,
    input i_start,

    output o_sclk,
    inout io_sdat,

    output o_oen,            // 1: io_sdat output; 0: input
	output o_finished
);
    parameter [23:0] LEFT_LINE_IN                   = 24'b0011_0100_000_0000_0_1001_0111;
    parameter [23:0] RIGHT_LINE_IN                  = 24'b0011_0100_000_0001_0_1001_0111;
    parameter [23:0] LEFT_HEADPHONE_OUT             = 24'b0011_0100_000_0010_0_0111_1001;
    parameter [23:0] RIGHT_HEADPHONE_OUT            = 24'b0011_0100_000_0011_0_0111_1001;
    parameter [23:0] ANALOGUE_AUDIO_PATH_CONTROL    = 24'b0011_0100_000_0100_0_0001_0101;
    parameter [23:0] DIGITAL_AUDIO_PATH_CONTROL     = 24'b0011_0100_000_0101_0_0000_0000;
    parameter [23:0] POWER_DOWN_CONTROL             = 24'b0011_0100_000_0110_0_0000_0000;
    parameter [23:0] DIGITAL_AUDIO_INTERFACE_FORMAT = 24'b0011_0100_000_0111_0_0100_0010;
    parameter [23:0] SAMPLING_CONTROL               = 24'b0011_0100_000_1000_0_0001_1001;
    parameter [23:0] ACTIVE_CONTROL                 = 24'b0011_0100_000_1001_0_0000_0001;

    localparam S_IDLE = 0;
    localparam S_START = 1;
    localparam S_SEND_BEFORE = 2;
    localparam S_SEND = 3;
    localparam S_ACK_BEFORE = 4;
    localparam S_ACK = 5;
    localparam S_STOP_BEFORE = 6;
	localparam S_STOP = 7;
	localparam S_KAPUTT = 8;        // optional
	
	reg [23:0] o_data_r, o_data_w;
    reg [3:0] state_r, state_w;
    reg [3:0] bit_ct_r, bit_ct_w;   // 8
    reg [1:0] byte_ct_r, byte_ct_w; // 3
    reg [3:0] comm_ct_r, comm_ct_w; // 10

    assign o_sclk = o_finished ? 1'b1 :
					(state_r == S_SEND_BEFORE || state_r == S_ACK_BEFORE || state_r == S_STOP) ? 1'b0 : 1'b1;

    wire o_sdat = (state_r == S_IDLE) ? 1'b1 :
                  (state_r == S_START || state_r == S_STOP_BEFORE) ? 1'b0 :
                  o_data_r[23];
	
	assign o_oen = (state_r == S_ACK_BEFORE || state_r == S_ACK) ? 1'b0 : 1'b1;

    assign io_sdat = o_oen ? o_sdat : 1'bz;

	assign o_finished = comm_ct_r == 10;

    always @(*) begin
        state_w = state_r;
        case(state_r)
            S_IDLE: if(i_start) state_w = S_START;
            S_START: state_w = S_SEND_BEFORE;
            S_SEND_BEFORE: state_w = S_SEND;
            S_SEND: begin
				if (bit_ct_r == 8) state_w = S_ACK_BEFORE;
				else state_w = S_SEND_BEFORE;
			end
            S_ACK_BEFORE:  state_w = S_ACK;
            S_ACK: begin
				if (io_sdat) state_w = S_KAPUTT;
				else if (byte_ct_r == 3) state_w = S_STOP_BEFORE;
				else state_w = S_SEND_BEFORE;
			end
			S_STOP_BEFORE: state_w = S_STOP;
            S_STOP: begin
				if (comm_ct_r == 10) state_w = S_IDLE;
				else state_w = S_START;
			end
			S_KAPUTT: begin                              // optional
				$display("Receive NACK. NO~~~~~");
				state_w = S_IDLE;
			end
            default: state_w = S_IDLE;
        endcase
    end

    always @(*) begin
        bit_ct_w = bit_ct_r;
        case(state_r)
            S_START: bit_ct_w = 0;
            S_SEND_BEFORE: bit_ct_w = bit_ct_r + 1;
            S_ACK_BEFORE: bit_ct_w = 0;
        endcase
    end

    always @(*) begin
        byte_ct_w = byte_ct_r;
        case(state_r)
            S_START: byte_ct_w = 0;
            S_ACK_BEFORE: byte_ct_w = byte_ct_r + 1;
        endcase
    end

    always @(*) begin
        comm_ct_w = comm_ct_r;
        case(state_r)
            S_ACK: if (byte_ct_r == 3) comm_ct_w = comm_ct_r + 1;
        endcase
    end

    always @(*) begin
        o_data_w = o_data_r;
        case(state_r)
            S_STOP: begin
                case(comm_ct_r)
                    1: o_data_w = RIGHT_LINE_IN;
                    2: o_data_w = LEFT_HEADPHONE_OUT;
                    3: o_data_w = RIGHT_HEADPHONE_OUT;
                    4: o_data_w = ANALOGUE_AUDIO_PATH_CONTROL;
                    5: o_data_w = DIGITAL_AUDIO_PATH_CONTROL;
                    6: o_data_w = POWER_DOWN_CONTROL;
                    7: o_data_w = DIGITAL_AUDIO_INTERFACE_FORMAT;
                    8: o_data_w = SAMPLING_CONTROL;
                    9: o_data_w = ACTIVE_CONTROL;
					default: o_data_w = 24'd0;
                endcase
            end
			S_SEND: if (bit_ct_r < 9) o_data_w = o_data_r << 1;
        endcase
    end

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            state_r   <= S_IDLE;
            bit_ct_r  <= 0;
            byte_ct_r <= 0;
            comm_ct_r <= 0;
            o_data_r  <= LEFT_LINE_IN;
        end 
        else begin
            state_r   <= state_w;
            bit_ct_r  <= bit_ct_w;
            byte_ct_r <= byte_ct_w;
            comm_ct_r <= comm_ct_w;
            o_data_r  <= o_data_w;
        end
    end
endmodule