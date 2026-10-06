module radar_correlator (
	input wire clk,
	input wire rst,
	input wire sample_in,
	output reg match_detected,
	output reg [7:0] correlation_score
);

reg [6:0] shift_reg;
always @(posedge clk or posedge rst) begin
	if (rst) begin
		shift_reg <= 7'b0;
		match_detected <= 1'b0;
		correlation_score <= 8'd0;
end else begin
	shift_reg <= {shift_reg[5:0], sample_in};
	if ({shift_reg[5:0], sample_in} == 7'b1110010) begin
		match_detected <= 1'b1;
		correlation_score <= 8'd7;
	end else begin
		match_detected <= 1'b0;
		correlation_score <= 8'd0;
	end
    end
end
endmodule
