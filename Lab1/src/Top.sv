module Top (
	input        i_clk,
	input        i_rst_n,
	input        i_start,
	output reg [3:0] o_random_out
);

// please check out the working example in lab1 README (or Top_exmaple.sv) first

// state declaration
parameter IDLE = 0, RUN_FAST = 1, RUN_SLOW = 2, DONE = 3;

// state
reg [1:0] state, next_state;

// counter
logic [31:0] counter;
logic [31:0] state_change_counter;
logic [31:0] seed;

// random generator
logic [3:0] rand_num;

logic gen;

lfsr_random_gen u_rand(.i_clk(i_clk), .i_rst_n(i_rst_n), .gen(gen), .seed(seed), .i_start(i_start), .random_out(rand_num));

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		state <= 0;
	end
	else begin
		state <= next_state;
	end
end

always_comb begin
	case (state)
		IDLE: next_state = i_start ? RUN_FAST : IDLE;
		RUN_FAST: next_state = (state_change_counter >= 125000000) ? RUN_SLOW : RUN_FAST;
		RUN_SLOW: next_state = (state_change_counter >= 250000000) ? DONE : RUN_SLOW;
		DONE: next_state = IDLE;
		default: next_state = IDLE;
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin
		gen <= 0;
		counter <= 0;
		state_change_counter <= 0;
		o_random_out <= 0;
		seed <= 0;
	end
	else begin
		seed <= seed + 1;
		case (state)
			IDLE: begin
				gen <= 0;
				counter <= 0;
				state_change_counter <= 0;
			end
			RUN_FAST: begin
				gen <= 1;
				if(counter >= 10000000 - 1) begin
					counter <= 0;
					o_random_out <= rand_num;
				end
				else begin
					counter <= counter + 1;
				end
				state_change_counter <= state_change_counter + 1;
			end
			RUN_SLOW: begin
				if(counter >= 25000000 - 1) begin
					counter <= 0;
					o_random_out <= rand_num;
				end
				else begin
					counter <= counter + 1;
				end
				state_change_counter <= state_change_counter + 1;
			end
			DONE: begin
				gen <= 0;
				state_change_counter <= 0;
			end
		endcase
	end
end

endmodule
