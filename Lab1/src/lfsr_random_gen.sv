module lfsr_random_gen(
  input  logic       i_clk,
  input  logic       i_rst_n,
  input  logic       gen,
  input  logic [31:0] seed,
  input  logic       i_start, 
  output logic [3:0] random_out
);

logic [10:0] lfsr_a;
logic [12:0] lfsr_b;
logic [16:0] lfsr_c;
logic [31:0] entropy_pool;
logic [31:0] comb;
logic [31:0] mulv;
logic [3:0]  random_reg;

always_ff @(posedge i_clk or negedge i_rst_n) begin
  if (!i_rst_n) begin
    lfsr_a <= 11'h1;
    lfsr_b <= 13'h1;
    lfsr_c <= 17'h1;
    entropy_pool <= seed;
    comb <= 32'h0;
    mulv <= 32'h0;
    random_reg <= 4'h0;
  end
  else if (i_start) begin
    random_reg <= 4'h0;
    entropy_pool <= seed;
  end
  else if (!gen) begin
    random_reg <= random_reg;
  end else begin
    logic fb_a;
    logic fb_b;
    logic fb_c;
    fb_a = lfsr_a[10] ^ lfsr_a[8];
    fb_b = lfsr_b[12] ^ lfsr_b[6] ^ lfsr_b[5] ^ lfsr_b[0];
    fb_c = lfsr_c[16] ^ lfsr_c[13];
    lfsr_a <= {lfsr_a[9:0], fb_a};
    lfsr_b <= {lfsr_b[11:0], fb_b};
    lfsr_c <= {lfsr_c[15:0], fb_c};
    entropy_pool <= (entropy_pool ^ 32'hdeadbeef) + {25'h0, lfsr_c[0], lfsr_b[0], lfsr_a[0], random_reg};
    comb <= {entropy_pool[0], lfsr_c, lfsr_b[3:0], lfsr_a[9:0]} ^ entropy_pool;
    mulv <= comb * 32'h9e3779b1;
    random_reg <= ( (mulv ^ (mulv >> 13) ^ (mulv << 7)) ) & 32'hf;
  end
end

assign random_out = random_reg;

endmodule