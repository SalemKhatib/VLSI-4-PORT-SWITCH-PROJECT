module switch_4port #(
	parameter NUM_PORTS  = 4,
	parameter DATA_WIDTH = 8
)(
	input  logic                  clk,
	input  logic                  rst_n,

	// 4 Input Interfaces
	port_if                       p0,
	port_if                       p1,
	port_if                       p2,
	port_if                       p3,

	// Shared Output Bus
	output logic                  valid_o,
	output logic [DATA_WIDTH-1:0] data_o,
	output logic [3:0]            dest_o
);

	// Internal arbitration signals
	logic [NUM_PORTS-1:0] reqs;
	logic [NUM_PORTS-1:0] grants;

	/*
	 * FIX:
	 * The arbiter's grant is registered, so a stale grant may remain
	 * asserted for a cycle after the corresponding request disappears.
	 *
	 * Mask the grant with the CURRENT requests so stale grants cannot
	 * drive old FIFO data onto the output.
	 */
	logic [NUM_PORTS-1:0] active_grants;

	assign active_grants = grants & reqs;


	// Internal buses from each port
	logic [DATA_WIDTH-1:0] data_bus [0:NUM_PORTS-1];
	logic [3:0]            dest_bus [0:NUM_PORTS-1];


	// ============================================================
	// Input ports
	// ============================================================

	switch_port p_inst0 (
		.clk         (clk),
		.rst_n       (rst_n),
		.p_if        (p0),
		.req_o       (reqs[0]),
		.dest_o      (dest_bus[0]),
		.grant_i     (grants[0]),
		.data_to_mux (data_bus[0])
	);

	switch_port p_inst1 (
		.clk         (clk),
		.rst_n       (rst_n),
		.p_if        (p1),
		.req_o       (reqs[1]),
		.dest_o      (dest_bus[1]),
		.grant_i     (grants[1]),
		.data_to_mux (data_bus[1])
	);

	switch_port p_inst2 (
		.clk         (clk),
		.rst_n       (rst_n),
		.p_if        (p2),
		.req_o       (reqs[2]),
		.dest_o      (dest_bus[2]),
		.grant_i     (grants[2]),
		.data_to_mux (data_bus[2])
	);

	switch_port p_inst3 (
		.clk         (clk),
		.rst_n       (rst_n),
		.p_if        (p3),
		.req_o       (reqs[3]),
		.dest_o      (dest_bus[3]),
		.grant_i     (grants[3]),
		.data_to_mux (data_bus[3])
	);


	// ============================================================
	// Arbiter
	// ============================================================

	arbiter arb_inst (
		.clk   (clk),
		.rst_n (rst_n),
		.req   (reqs),
		.grant (grants)
	);


	// ============================================================
	// Shared output mux
	// ============================================================

	always_comb begin

		data_o  = '0;
		dest_o  = '0;
		valid_o = 1'b0;

		case (active_grants)

			4'b0001: begin
				valid_o = 1'b1;
				data_o  = data_bus[0];
				dest_o  = dest_bus[0];
			end

			4'b0010: begin
				valid_o = 1'b1;
				data_o  = data_bus[1];
				dest_o  = dest_bus[1];
			end

			4'b0100: begin
				valid_o = 1'b1;
				data_o  = data_bus[2];
				dest_o  = dest_bus[2];
			end

			4'b1000: begin
				valid_o = 1'b1;
				data_o  = data_bus[3];
				dest_o  = dest_bus[3];
			end

			default: begin
				valid_o = 1'b0;
				data_o  = '0;
				dest_o  = '0;
			end

		endcase
	end


	// ============================================================
	// Output distribution / multicast
	// ============================================================

	always_comb begin

		// Defaults
		p0.valid_out  = 1'b0;
		p0.data_out   = '0;
		p0.source_out = '0;
		p0.target_out = '0;

		p1.valid_out  = 1'b0;
		p1.data_out   = '0;
		p1.source_out = '0;
		p1.target_out = '0;

		p2.valid_out  = 1'b0;
		p2.data_out   = '0;
		p2.source_out = '0;
		p2.target_out = '0;

		p3.valid_out  = 1'b0;
		p3.data_out   = '0;
		p3.source_out = '0;
		p3.target_out = '0;


		if (valid_o) begin

			if (dest_o[0]) begin
				p0.valid_out  = 1'b1;
				p0.data_out   = data_o;
				p0.target_out = dest_o;
				p0.source_out = active_grants;
			end

			if (dest_o[1]) begin
				p1.valid_out  = 1'b1;
				p1.data_out   = data_o;
				p1.target_out = dest_o;
				p1.source_out = active_grants;
			end

			if (dest_o[2]) begin
				p2.valid_out  = 1'b1;
				p2.data_out   = data_o;
				p2.target_out = dest_o;
				p2.source_out = active_grants;
			end

			if (dest_o[3]) begin
				p3.valid_out  = 1'b1;
				p3.data_out   = data_o;
				p3.target_out = dest_o;
				p3.source_out = active_grants;
			end

		end
	end

endmodule