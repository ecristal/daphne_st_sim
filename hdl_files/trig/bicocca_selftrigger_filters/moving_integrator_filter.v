`timescale 1ns/10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 1, 2022, 5:51:46 PM
// Design Name: filtering_and_selftrigger
// Module Name: moving_integrator_filter.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module moving_integrator_filter(
	input wire clk,
	input wire reset, 
	input wire enable, 
	input wire signed [15:0] x,
    output wire signed [15:0] y,
    output wire signed [15:0] x_delayed
);
    
	parameter k = 31;
    
    reg reset_reg, enable_reg;
    reg signed [15:0] in_reg;
	reg signed [15:0] y_1_32, y_out_32, x_out_aux0, x_out_aux1, x_out_aux2, x_out_aux3; 
	reg signed [15:0] wm_32; 
    
    wire signed [15:0] w2; 
	wire signed [21:0] w1; 


	always @(posedge clk) begin 
		if(reset) begin
			reset_reg <= 1'b1;
			enable_reg <= 1'b0;
		end else if (enable) begin
			reset_reg <= 1'b0;
			enable_reg <= 1'b1;
		end else begin 
			reset_reg <= 1'b0;
			enable_reg <= 1'b0;
		end
	end

	always @(posedge clk) begin
		if(reset_reg) begin
			y_1_32 <= 0;
			in_reg <= 0;
			x_out_aux0 <= 0;
			x_out_aux1 <= 0;
			x_out_aux2 <= 0;
			x_out_aux3 <= 0;
		end else if(enable_reg) begin
			wm_32 <= {w1[21],w1[19:5]};
			y_out_32 <= wm_32 + $signed(4);
			x_out_aux0 <= w2;
			x_out_aux1 <= x_out_aux0;
			x_out_aux2 <= x_out_aux1;
			x_out_aux3 <= x_out_aux2;
			y_1_32 <= w1;
			in_reg <= x;
		end
	end

	generate genvar i;
		for(i=0; i<=15; i=i+1) begin : srlc32e_i_inst
				SRLC32E #(
				   .INIT(32'h00000000),    // Initial contents of shift register
				   .IS_CLK_INVERTED(1'b0)  // Optional inversion for CLK
					) 
					SRLC32E_inst_1 (
				   .Q(w2[i]),     // 1-bit output: SRL Data
				   .Q31(), // 1-bit output: SRL Cascade Data
				   .A(k),     // 5-bit input: Selects SRL depth
				   .CE(enable_reg),   // 1-bit input: Clock enable
				   .CLK(clk), // 1-bit input: Clock
				   .D(in_reg[i])      // 1-bit input: SRL Data
				);
		end
	endgenerate

	assign w1 = in_reg + y_1_32 - w2;
    assign y = y_out_32;
    assign x_delayed = x_out_aux3;

endmodule