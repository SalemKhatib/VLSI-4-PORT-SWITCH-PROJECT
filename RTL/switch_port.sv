module switch_port #(
	parameter WIDTH = 8,        // Data Width
	parameter DEPTH = 16        // FIFO Depth
)(
	input  logic             clk,
	input  logic             rst_n,
	port_if                  p_if,
	output logic             req_o,
	output logic [3:0]       dest_o,
	input  logic             grant_i,
	output logic [WIDTH-1:0] data_to_mux
);

	// --- POINTER SIZES ---
	localparam PTR_BITS = $clog2(DEPTH);
	localparam CNT_BITS = $clog2(DEPTH + 1);

	// --- INTERNAL SIGNALS ---
	logic [WIDTH-1:0]    fifo_data [0:DEPTH-1];
	logic [3:0]          fifo_dest [0:DEPTH-1];

	logic [PTR_BITS-1:0] wr_ptr;
	logic [PTR_BITS-1:0] rd_ptr;

	logic [CNT_BITS-1:0] count;

	logic full;
	logic writing;
	logic reading;


	// --- FSM STATE DEF ---
	typedef enum logic [1:0] {
		S_IDLE,
		S_REQUEST,
		S_TRANSMIT
	} state_t;

	state_t current_state;
	state_t next_state;


	// ============================================================
	// FIFO STATUS / FLOW CONTROL
	// ============================================================

	assign full = (count == DEPTH);

	/*
	 * If FIFO isn't full -> ready.
	 *
	 * If FIFO IS full but we're removing one packet this cycle,
	 * we can simultaneously accept a new packet.
	 */
	assign p_if.ready = (!full || reading);

	/*
	 * FIX:
	 * Only write when the input transaction is actually accepted.
	 *
	 * OLD:
	 * writing = valid_in &&
	 *           (!full || current_state == S_TRANSMIT);
	 *
	 * That could write to a full FIFO even when we were not granted.
	 */
	assign writing = p_if.valid_in && p_if.ready;


	// ============================================================
	// 1. FSM STATE REGISTER
	// ============================================================

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			current_state <= S_IDLE;
		else
			current_state <= next_state;
	end


	// ============================================================
	// 2. FSM NEXT-STATE / READ CONTROL
	// ============================================================

	always_comb begin

		next_state = current_state;

		req_o   = 1'b0;
		reading = 1'b0;


		case (current_state)

			// ----------------------------------------------------
			// Nothing currently waiting for arbitration
			// ----------------------------------------------------
			S_IDLE: begin

				if (count > 0)
					next_state = S_REQUEST;

			end


			// ----------------------------------------------------
			// FIFO contains data and we're asking for the bus
			// ----------------------------------------------------
			S_REQUEST: begin

				req_o = 1'b1;

				/*
				 * FIX:
				 *
				 * grant_i means this FIFO head is actually being
				 * placed on the shared output bus.
				 *
				 * Therefore we must consume that packet in THIS
				 * granted cycle.
				 */
				if (grant_i) begin

					reading = 1'b1;

					/*
					 * count is the value BEFORE this read.
					 *
					 * count > 1:
					 * another packet will remain after this one.
					 *
					 * count == 1:
					 * this was the final packet.
					 */
					if (count > 1)
						next_state = S_TRANSMIT;
					else
						next_state = S_IDLE;

				end

			end


			// ----------------------------------------------------
			// Previous transaction was granted; try to continue
			// burst transmission
			// ----------------------------------------------------
			S_TRANSMIT: begin

				req_o = 1'b1;

				/*
				 * CRITICAL FIX:
				 *
				 * NEVER increment rd_ptr unless we actually own
				 * the grant.
				 */
				if (grant_i) begin

					reading = 1'b1;

					if (count > 1)
						next_state = S_TRANSMIT;
					else
						next_state = S_IDLE;

				end
				else begin

					/*
					 * We lost arbitration.
					 *
					 * Keep the packet in the FIFO and request again.
					 */
					reading    = 1'b0;
					next_state = S_REQUEST;

				end

			end


			default: begin

				req_o      = 1'b0;
				reading    = 1'b0;
				next_state = S_IDLE;

			end

		endcase
	end


	// ============================================================
	// 3. FIFO LOGIC
	// ============================================================

	always_ff @(posedge clk or negedge rst_n) begin

		if (!rst_n) begin

			wr_ptr <= '0;
			rd_ptr <= '0;
			count  <= '0;

		end
		else begin

			// ----------------------------------------------------
			// WRITE
			// ----------------------------------------------------

			if (writing) begin

				fifo_data[wr_ptr] <= p_if.data_in;
				fifo_dest[wr_ptr] <= p_if.target_in;

				wr_ptr <= wr_ptr + 1'b1;

			end


			// ----------------------------------------------------
			// READ
			// ----------------------------------------------------

			if (reading) begin

				rd_ptr <= rd_ptr + 1'b1;

			end


			// ----------------------------------------------------
			// FIFO COUNT
			// ----------------------------------------------------

			case ({writing, reading})

				// Write only
				2'b10:
					count <= count + 1'b1;

				// Read only
				2'b01:
					count <= count - 1'b1;

				/*
				 * Simultaneous read + write:
				 * count remains unchanged.
				 *
				 * No read + no write:
				 * count remains unchanged.
				 */
				default:
					count <= count;

			endcase

		end
	end


	// ============================================================
	// 4. FIFO HEAD OUTPUTS
	// ============================================================

	assign dest_o      = fifo_dest[rd_ptr];
	assign data_to_mux = fifo_data[rd_ptr];


endmodule