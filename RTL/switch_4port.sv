module switch_4port #(
	parameter NUM_PORTS = 4,
	parameter DATA_WIDTH = 8
)(
	input  logic        clk,
	input  logic        rst_n,

	// 4 Input Interfaces
	port_if             p0,
	port_if             p1,
	port_if             p2,
	port_if             p3,

	// The Shared Output Bus 
	output logic        valid_o,
	output logic [DATA_WIDTH-1:0]  data_o,
	output logic [3:0]  dest_o
);

	// INTERNAL SIGNALS 
	logic [NUM_PORTS-1:0] reqs;
	logic [NUM_PORTS-1:0] grants;
	
	// Internal Buses to gather data from all ports
	logic [DATA_WIDTH-1:0] data_bus [0:NUM_PORTS-1];
	logic [3:0]            dest_bus [0:NUM_PORTS-1];

	// 1. INSTANTIATE PORTS 
	switch_port p_inst0 (
		.clk(clk), .rst_n(rst_n),
		.p_if(p0),
		.req_o(reqs[0]), .grant_i(grants[0]),
		.dest_o(dest_bus[0]), .data_to_mux(data_bus[0])
	);

	switch_port p_inst1 (
		.clk(clk), .rst_n(rst_n),
		.p_if(p1),
		.req_o(reqs[1]), .grant_i(grants[1]),
		.dest_o(dest_bus[1]), .data_to_mux(data_bus[1])
	);

	switch_port p_inst2 (
		.clk(clk), .rst_n(rst_n),
		.p_if(p2),
		.req_o(reqs[2]), .grant_i(grants[2]),
		.dest_o(dest_bus[2]), .data_to_mux(data_bus[2])
	);

	switch_port p_inst3 (
		.clk(clk), .rst_n(rst_n),
		.p_if(p3),
		.req_o(reqs[3]), .grant_i(grants[3]),
		.dest_o(dest_bus[3]), .data_to_mux(data_bus[3])
	);

	//  2. ARBITER 
	arbiter arb_inst (
		.clk(clk), .rst_n(rst_n),
		.req(reqs), .grant(grants)
	);

	//  3. MULTIPLEXER (MUX) 
	// Selects ONE winner to put on the central bus
	always_comb begin
		data_o  = '0;
		dest_o  = '0;
		valid_o = 1'b0;

		case (grants)
			4'b0001: begin valid_o=1; data_o=data_bus[0]; dest_o=dest_bus[0]; end
			4'b0010: begin valid_o=1; data_o=data_bus[1]; dest_o=dest_bus[1]; end
			4'b0100: begin valid_o=1; data_o=data_bus[2]; dest_o=dest_bus[2]; end
			4'b1000: begin valid_o=1; data_o=data_bus[3]; dest_o=dest_bus[3]; end
			default: valid_o = 0;
		endcase
	end

	// 4. OUTPUT DISTRIBUTION
	// This looks at the central bus and sends data to the correct Interface
	always_comb begin
		// A. Reset everyone to 0 first
		p0.valid_out = 0; p0.data_out = 0; p0.source_out = 0; p0.target_out = 0;
		p1.valid_out = 0; p1.data_out = 0; p1.source_out = 0; p1.target_out = 0;
		p2.valid_out = 0; p2.data_out = 0; p2.source_out = 0; p2.target_out = 0;
		p3.valid_out = 0; p3.data_out = 0; p3.source_out = 0; p3.target_out = 0;

		// B. If we have valid data check which port:
		if (valid_o) begin
			
			// If Target Bit 0 is set -> Send to Port 0
			if (dest_o[0]) begin
				p0.valid_out = 1;
				p0.data_out  = data_o;
				p0.target_out = dest_o;
				p0.source_out = grants;
			end

			// If Target Bit 1 is set -> Send to Port 1
			if (dest_o[1]) begin
				p1.valid_out = 1;
				p1.data_out  = data_o;
				p1.target_out = dest_o;
				p1.source_out = grants;
			end

			// If Target Bit 2 is set -> Send to Port 2
			if (dest_o[2]) begin
				p2.valid_out = 1;
				p2.data_out  = data_o;
				p2.target_out = dest_o;
				p2.source_out = grants;
			end

			// If Target Bit 3 is set -> Send to Port 3
			if (dest_o[3]) begin
				p3.valid_out = 1;
				p3.data_out  = data_o;
				p3.target_out = dest_o;
				p3.source_out = grants;
			end
		end
	end

endmodule