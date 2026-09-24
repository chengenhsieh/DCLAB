module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a,
	input  [255:0] i_d,
	input  [255:0] i_n,
	output [255:0] o_a_pow_d,
	output         o_finished
	);

	parameter S_IDLE = 2'd0;
	parameter S_PREP = 2'd1;
	parameter S_MONT = 2'd2;
	parameter S_CALC = 2'd3;
	reg [1:0] state_r, state_w;

	reg [8:0] counter_r, counter_w;

	reg mont_start_r, mont_start_w;	// mont_Nmt & mont_Ntt start at the same time

	reg [255:0] d_r, d_w;			// use d_r[0] to determine whether to update m
	reg [255:0] t_r, t_w;
	reg [255:0] m_r, m_w;

	reg o_finished_r, o_finished_w;
	assign o_finished = o_finished_r;
    assign o_a_pow_d = m_r;
	
	wire [255:0] prep_result;
	wire prep_finished;
	RsaPrep prep(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(i_start),
		.i_a(i_a),
		.i_n(i_n),
		.o_result(prep_result),
		.o_finished(prep_finished)
	);

	wire [255:0] mont_Nmt_result;
	wire mont_Nmt_finished;
	RsaMont mont_Nmt(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(mont_start_r),
		.i_n(i_n),
		.i_a(m_r),
		.i_b(t_r),
		.o_result(mont_Nmt_result),
		.o_finished(mont_Nmt_finished)
	);

	wire [255:0] mont_Ntt_result;
	wire mont_Ntt_finished;
	RsaMont mont_Ntt(
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_start(mont_start_r),
		.i_n(i_n),
		.i_a(t_r),
		.i_b(t_r),
		.o_result(mont_Ntt_result),
		.o_finished(mont_Ntt_finished)
	);

	always_comb begin
		state_w = state_r;
		case(state_r)
			S_IDLE: begin
				if(i_start) state_w = S_PREP;
				else		state_w = S_IDLE;
			end
			S_PREP: begin
				if(prep_finished) state_w = S_MONT;
				else			  state_w = S_PREP;
			end
			S_MONT: begin
				if(mont_Nmt_finished && mont_Ntt_finished) state_w = S_CALC;
				else									   state_w = S_MONT;
			end
			S_CALC: begin
				if(counter_r == 9'd256) state_w = S_IDLE;
				else			        state_w = S_MONT;
			end
		endcase
	end

	always_comb begin
		counter_w = counter_r;
		case(state_r)
			S_IDLE: counter_w = 0;
			S_CALC: counter_w = counter_r + 1;
		endcase
	end

	always_comb begin
        mont_start_w = (state_w == S_MONT && state_r != S_MONT) ? 1'b1 : 1'b0;
	end

	always_comb begin
		d_w = d_r;
		case(state_r)
			S_IDLE: if(i_start) d_w = i_d;
			S_CALC: d_w = d_r >> 1;
		endcase
	end

	always_comb begin
		t_w = t_r;
		case(state_r)
			S_PREP: if(prep_finished) t_w = prep_result;
			S_MONT: if(mont_Ntt_finished) t_w = mont_Ntt_result;
		endcase
	end

	always_comb begin
		m_w = m_r;
		case(state_r)
			S_PREP: m_w = 256'd1;
			S_MONT: if(mont_Nmt_finished && d_r[0])	m_w = mont_Nmt_result;
		endcase
	end

	always_comb begin
		o_finished_w = 1'b0;
		case(state_r)
			S_CALC: if(counter_r == 9'd256) o_finished_w = 1'b1;
		endcase
	end

	always_ff @(posedge i_clk or posedge i_rst) begin
		if(i_rst) begin
			state_r <= S_IDLE;
			counter_r <= 9'd0;
			t_r <= 256'd0;
			m_r <= 256'd1;
			d_r <= 256'd0;
			mont_start_r <= 1'b0;
			o_finished_r <= 1'b0;
		end
		else begin
			state_r <= state_w;
			counter_r <= counter_w;
			t_r <= t_w;
			m_r <= m_w;
			d_r <= d_w;
			mont_start_r <= mont_start_w;
			o_finished_r <= o_finished_w;
		end
	end
endmodule

module RsaPrep (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a,
	input  [255:0] i_n,
	output [255:0] o_result,
	output         o_finished
	);

    // Adjustable parameters
    localparam integer WIDTH = 128;               // need to be 2^n 
    localparam integer CHUNKS = 256 / WIDTH; 
    localparam integer CNT_W = $clog2(CHUNKS);
	logic [CNT_W-1:0] counter_r, counter_w;

	parameter S_IDLE = 2'd0;
	parameter S_CALC = 2'd1;
	parameter S_DONE = 2'd2;
	logic [1:0] state_r, state_w;

	logic [255:0] o_result_r, o_result_w;
	logic o_finished_r, o_finished_w;
	assign o_result = o_result_r;
	assign o_finished = o_finished_r;

	always_comb begin
		state_w = state_r;
		case(state_r)
			S_IDLE: begin
				if(i_start) state_w = S_CALC;
				else		state_w = S_IDLE;
			end
			S_CALC: begin
				if(counter_r == CHUNKS-1) state_w = S_DONE;
				else				      state_w = S_CALC;
			end
			S_DONE:  state_w = S_IDLE;
		endcase
	end

	always_comb begin
		counter_w = counter_r;
		case(state_r)
			S_CALC:  counter_w = counter_r + 1;
			default: counter_w = 0;
		endcase
	end

	logic [256:0] temp_shift;
    integer i;
	always_comb begin
		o_result_w = o_result_r;
		case(state_r)
			S_IDLE: if(i_start) o_result_w = i_a;
			S_CALC: begin
                temp_shift = { 1'b0, o_result_r };
                for (i = 0; i < WIDTH; i = i + 1) begin
                    temp_shift = temp_shift << 1;
                    if (temp_shift >= i_n) temp_shift = temp_shift - i_n;
                end
                o_result_w = temp_shift[255:0];
			end
		endcase
	end

	always_comb begin
		o_finished_w = 1'b0;
		case(state_r)
			S_CALC: if(counter_r == CHUNKS-1) o_finished_w = 1'b1;
		endcase
	end

	always_ff @(posedge i_clk or posedge i_rst) begin
		if(i_rst) begin
			state_r <= S_IDLE;
			counter_r <= {CNT_W{1'b0}};
			o_result_r <= 256'd0;
			o_finished_r <= 1'b0;
		end
		else begin
			state_r <= state_w;
			counter_r <= counter_w;
			o_result_r <= o_result_w;
			o_finished_r <= o_finished_w;
		end
	end
endmodule

module RsaMont (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_n,
	input  [255:0] i_a,
	input  [255:0] i_b,
	output [255:0] o_result,
	output         o_finished
	);    // calculate a*b*2^(-256) mod n; assume n is odd & 0<=b<n

    // Adjustable parameter
    localparam integer WIDTH = 128;               
    localparam integer CHUNKS = 256 / WIDTH;
    localparam integer CNT_W = $clog2(CHUNKS);
	logic [CNT_W-1:0] counter_r, counter_w;

	parameter S_IDLE = 2'd0;
	parameter S_CALC = 2'd1;
	parameter S_DONE = 2'd2;
	logic [1:0] state_r, state_w;

	logic [255:0] a_r, a_w;

	logic [256+1:0] o_result_r, o_result_w;
	logic o_finished_r, o_finished_w;
	assign o_result = o_result_r[255:0];
	assign o_finished = o_finished_r;

	always_comb begin
		state_w = state_r;
		case(state_r)
			S_IDLE: begin
				if(i_start) state_w = S_CALC;
				else		state_w = S_IDLE;
			end
			S_CALC: begin
				if(counter_r == CHUNKS-1) state_w = S_DONE;
				else				      state_w = S_CALC;
			end
			S_DONE:  state_w = S_IDLE;
		endcase
	end

	always_comb begin
		counter_w = counter_r;
		case(state_r)
			S_CALC:  counter_w = counter_r + 1;
			default: counter_w = {CNT_W{1'b0}};
		endcase
	end

	always_comb begin
		a_w = a_r;
		case(state_r)
			S_IDLE: if(i_start) a_w = i_a;
			S_CALC: a_w = (a_r >> WIDTH);
		endcase
	end

    logic [WIDTH-1:0] bit_mask_dummy;
	logic [257:0] temp1, temp2, temp3;
    logic [255:0] a_temp;
    integer i;
	always_comb begin
		o_result_w = o_result_r;
		if(counter_r == 0) o_result_w = 257'd0;
		case(state_r)
			S_CALC: begin
                temp1 = o_result_r;
                a_temp = a_r;
                for (i = 0; i < WIDTH; i = i + 1) begin
                    if(a_temp[0]) temp1 = temp1 + i_b;
                    if(temp1[0])	temp2 = temp1 + i_n;
                    else			temp2 = temp1;
                    temp3 = temp2 >> 1;
                    temp1 = temp3;
                    a_temp = a_temp >> 1;
                end

				if(counter_r == CHUNKS-1) begin
					if(temp3 >= i_n)	o_result_w = temp3 - i_n;
					else 				o_result_w = temp3;
				end
				else o_result_w = temp3;
			end
		endcase
	end

	always_comb begin
		o_finished_w = 1'b0;
		case(state_r)
			S_CALC: if(counter_r == CHUNKS-1) o_finished_w = 1'b1;
		endcase
	end

	always_ff @(posedge i_clk or posedge i_rst) begin
		if(i_rst) begin
			state_r <= S_IDLE;
			counter_r <= {CNT_W{1'b0}};
			a_r <= 256'd0;
			o_result_r <= 257'd0;
			o_finished_r <= 1'b0;
		end
		else begin
			state_r <= state_w;
			counter_r <= counter_w;
			a_r <= a_w;
			o_result_r <= o_result_w;
			o_finished_r <= o_finished_w;
		end
	end
endmodule