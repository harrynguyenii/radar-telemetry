`timescale 1ns/1ps

module tb_radar_correlator;
	reg clk;
	reg rst;
	reg sample_in;
	wire match_detected;
	wire [7:0] correlation_score;

	radar_correlator uut (
		.clk(clk),
		.rst(rst),
		.sample_in(sample_in),
		.match_detected(match_detected),
		.correlation_score(correlation_score)
	);

	always #10 clk = ~clk;
	integer i;	

	initial begin
		clk = 0;
		rst = 1;
		sample_in = 0;
		#25;

		rst = 0;
		#20;

		for (i = 0; i < 15; i = i + 1) begin
			sample_in = $random % 2;
			#20;
		end

		sample_in = 0; #20;
		sample_in = 1; #20;
		sample_in = 0; #20;
		sample_in = 0; #20;
		sample_in = 1; #20;
		sample_in = 1; #20;
		sample_in = 1; #20;
		
		// Feed random noise stream
		for (i = 0; i < 10; i = i + 1) begin
			sample_in = $random % 2;
		end
		
		#100;
		$finish;
	end

	initial begin
		$monitor("Time=%0t | Sample=%b | Match=%b | Score=%d", $time, sample_in, match_detected, correlation_score);
	end
endmodule

