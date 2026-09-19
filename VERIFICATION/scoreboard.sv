`include "coverage.sv"

class scoreboard extends component_base;

	mailbox #(packet) exp_mbx[4];
	mailbox #(packet) act_mbx[4];

	packet q0[$];
	packet q1[$];
	packet q2[$];
	packet q3[$];

	switch_coverage cov;

	int match_count;
	int mismatch_count;
	int generated_per_src[4];

	semaphore count_lock;


	// ============================================================
	// CONSTRUCTOR
	// ============================================================

	function new(string name, component_base parent=null);

		super.new(name, parent);

		cov = new();

		count_lock = new(1);

		match_count    = 0;
		mismatch_count = 0;

		for (int i = 0; i < 4; i++) begin
			generated_per_src[i] = 0;
		end

	endfunction


	// ============================================================
	// RUN
	// ============================================================

	task run();

		fork

			monitor_expected(0);
			monitor_expected(1);
			monitor_expected(2);
			monitor_expected(3);

			monitor_actual(0);
			monitor_actual(1);
			monitor_actual(2);
			monitor_actual(3);

		join_none

	endtask


	// ============================================================
	// PREDICTOR
	// ============================================================

	task monitor_expected(int port_id);

		packet pkt;
		packet clone;
		int i;

		forever begin

			/*
			 * Receive a packet generated for this input/source port.
			 */
			exp_mbx[port_id].get(pkt);

			generated_per_src[port_id]++;


			// ----------------------------------------------------
			// Functional coverage
			// ----------------------------------------------------

			for (i = 0; i < 4; i++) begin

				if (pkt.target[i] == 1'b1)
					cov.sample(pkt, i);

			end


			// ----------------------------------------------------
			// Build expected output queues
			//
			// For multicast:
			//
			// target = 1011
			//
			// creates one expected packet in:
			//
			// Port 0
			// Port 1
			// Port 3
			// ----------------------------------------------------

			for (i = 0; i < 4; i++) begin

				if (pkt.target[i] == 1'b1) begin

					clone = pkt.clone();

					case (i)

						0:
							q0.push_back(clone);

						1:
							q1.push_back(clone);

						2:
							q2.push_back(clone);

						3:
							q3.push_back(clone);

					endcase

				end

			end

		end

	endtask


	// ============================================================
	// CHECKER
	// ============================================================

	task monitor_actual(int port_id);

		packet act_pkt;

		int found_idx;
		int q_size;

		forever begin

			/*
			 * Wait for one actual output transaction.
			 */
			act_mbx[port_id].get(act_pkt);


			// ----------------------------------------------------
			// IMPORTANT:
			//
			// There is intentionally NO "last_pkt" filtering here.
			//
			// If two identical packets are legitimately transmitted:
			//
			//   Src=2 Target=0100 Data=6b
			//   Src=2 Target=0100 Data=6b
			//
			// they are TWO real transactions and both must be checked.
			// ----------------------------------------------------


			// ----------------------------------------------------
			// Get expected queue size
			// ----------------------------------------------------

			q_size = 0;

			case (port_id)

				0:
					q_size = q0.size();

				1:
					q_size = q1.size();

				2:
					q_size = q2.size();

				3:
					q_size = q3.size();

			endcase


			// ----------------------------------------------------
			// Actual packet arrived but nothing was expected
			// ----------------------------------------------------

			if (q_size == 0) begin

				count_lock.get(1);

				mismatch_count++;

				count_lock.put(1);


				$display(
					"[SCB] FAIL: Unexpected packet at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id,
					act_pkt.source,
					act_pkt.target,
					act_pkt.data
				);

				continue;

			end


			// ----------------------------------------------------
			// Look for this actual packet in the expected queue
			// ----------------------------------------------------

			found_idx = -1;

			case (port_id)

				0:
					found_idx = find_packet(q0, act_pkt);

				1:
					found_idx = find_packet(q1, act_pkt);

				2:
					found_idx = find_packet(q2, act_pkt);

				3:
					found_idx = find_packet(q3, act_pkt);

			endcase


			// ----------------------------------------------------
			// MATCH
			// ----------------------------------------------------

			if (found_idx != -1) begin

				/*
				 * Delete exactly ONE expected occurrence.
				 *
				 * This is important when two identical packets exist.
				 */
				case (port_id)

					0:
						q0.delete(found_idx);

					1:
						q1.delete(found_idx);

					2:
						q2.delete(found_idx);

					3:
						q3.delete(found_idx);

				endcase


				count_lock.get(1);

				match_count++;

				count_lock.put(1);


				$display(
					"[SCB] PASS: Match at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id,
					act_pkt.source,
					act_pkt.target,
					act_pkt.data
				);

			end


			// ----------------------------------------------------
			// UNMATCHED OUTPUT
			// ----------------------------------------------------

			else begin

				/*
				 * Do NOT silently throw this packet away.
				 *
				 * The original scoreboard had a "Garbage Filter"
				 * here. The strict scoreboard must report it.
				 */

				count_lock.get(1);

				mismatch_count++;

				count_lock.put(1);


				$display(
					"[SCB] FAIL: Unmatched packet at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id,
					act_pkt.source,
					act_pkt.target,
					act_pkt.data
				);

			end

		end

	endtask


	// ============================================================
	// FIND PACKET
	// ============================================================

	function int find_packet(
		ref packet q[$],
		input packet p_in
	);

		int i;

		for (i = 0; i < q.size(); i++) begin

			if (
				q[i].source == p_in.source &&
				q[i].data   == p_in.data   &&
				q[i].target == p_in.target
			)
				return i;

		end

		return -1;

	endfunction


	// ============================================================
	// DEBUG: DUMP EXPECTED QUEUE
	// ============================================================

	function void dump_queue(int p);

		$display(
			"      --- Expected Queue for Port %0d (First 5 items) ---",
			p
		);

		if (p == 0)
			print_q(q0);

		if (p == 1)
			print_q(q1);

		if (p == 2)
			print_q(q2);

		if (p == 3)
			print_q(q3);

		$display(
			"      ---------------------------------------------------"
		);

	endfunction


	// ============================================================
	// DEBUG: PRINT QUEUE
	// ============================================================

	function void print_q(ref packet q[$]);

		int limit;
		int i;

		limit = (q.size() > 5) ? 5 : q.size();


		if (q.size() == 0)
			$display("      [EMPTY]");


		for (i = 0; i < limit; i++) begin

			$display(
				"      [%0d] Exp Src=%0d Target=%b Data=%h",
				i,
				q[i].source,
				q[i].target,
				q[i].data
			);

		end

	endfunction


	// ============================================================
	// FINAL REPORT
	// ============================================================

	function void report();

		int pending_count;
		int generated_count;
		int observed_count;
		int expected_destination_count;

		real coverage_pct;


		// --------------------------------------------------------
		// Remaining expected packets = packets DUT never produced
		// --------------------------------------------------------

		pending_count =
			q0.size() +
			q1.size() +
			q2.size() +
			q3.size();


		// --------------------------------------------------------
		// Total generated input packets
		// --------------------------------------------------------

		generated_count =
			generated_per_src[0] +
			generated_per_src[1] +
			generated_per_src[2] +
			generated_per_src[3];


		// --------------------------------------------------------
		// Every actual output was either:
		//
		// MATCH
		// or
		// MISMATCH
		//
		// There is NO duplicate suppression anymore.
		// --------------------------------------------------------

		observed_count =
			match_count +
			mismatch_count;


		// --------------------------------------------------------
		// Expected destination transactions
		//
		// matched + still waiting
		// --------------------------------------------------------

		expected_destination_count =
			match_count +
			pending_count;


		coverage_pct =
			cov.cg_packet.get_inst_coverage();


		// --------------------------------------------------------
		// REPORT
		// --------------------------------------------------------

		$display("\n====================================================");

		$display(
			"             STRICT SCOREBOARD REPORT               "
		);

		$display(
			" Generated input packets:          %0d",
			generated_count
		);

		$display(
			" Expected destination events:      %0d",
			expected_destination_count
		);

		$display(
			" Observed destination events:      %0d",
			observed_count
		);

		$display(
			" Matched destination events:       %0d",
			match_count
		);

		$display(
			" Unexpected/unmatched events:      %0d",
			mismatch_count
		);

		$display(
			" Missing expected events:          %0d",
			pending_count
		);

		$display(
			" Source x destination coverage:    %0.2f%%",
			coverage_pct
		);


		// --------------------------------------------------------
		// PASS / FAIL
		// --------------------------------------------------------

		if (
			(generated_count > 0) &&
			(mismatch_count == 0) &&
			(pending_count == 0)
		)
			$display(" STATUS: PASSED");

		else
			$display(" STATUS: FAILED");


		$display(
			"====================================================\n"
		);


		// --------------------------------------------------------
		// Print remaining expected packets on failure
		// --------------------------------------------------------

		if (pending_count != 0) begin

			dump_queue(0);
			dump_queue(1);
			dump_queue(2);
			dump_queue(3);

		end

	endfunction


endclass