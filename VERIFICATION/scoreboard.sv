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

	function new(string name, component_base parent=null);
		super.new(name, parent);
		cov = new();
		count_lock = new(1);
		match_count = 0;
		mismatch_count = 0;
		for (int i = 0; i < 4; i++)
			generated_per_src[i] = 0;
	endfunction

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

	// Predictor: consume generated packets, sample coverage, and build
	// one expected queue entry for every destination bit in the target mask.
	task monitor_expected(int port_id);
		packet pkt;
		packet clone;
		int i;

		forever begin
			exp_mbx[port_id].get(pkt);
			generated_per_src[port_id]++;

			for (i = 0; i < 4; i++) begin
				if (pkt.target[i] == 1'b1)
					cov.sample(pkt, i);
			end

			for (i = 0; i < 4; i++) begin
				if (pkt.target[i] == 1'b1) begin
					clone = pkt.clone();
					case (i)
						0: q0.push_back(clone);
						1: q1.push_back(clone);
						2: q2.push_back(clone);
						3: q3.push_back(clone);
					endcase
				end
			end
		end
	endtask

	// Checker: every observed transaction must consume exactly one
	// matching expected queue entry. Identical packets are not suppressed;
	// they are independent transactions when multiple copies are expected.
	task monitor_actual(int port_id);
		packet act_pkt;
		int found_idx;
		int q_size;

		forever begin
			act_mbx[port_id].get(act_pkt);

			q_size = 0;
			case (port_id)
				0: q_size = q0.size();
				1: q_size = q1.size();
				2: q_size = q2.size();
				3: q_size = q3.size();
			endcase

			if (q_size == 0) begin
				count_lock.get(1);
				mismatch_count++;
				count_lock.put(1);

				$display(
					"[SCB] FAIL: Unexpected packet at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id, act_pkt.source, act_pkt.target, act_pkt.data
				);
				continue;
			end

			found_idx = -1;
			case (port_id)
				0: found_idx = find_packet(q0, act_pkt);
				1: found_idx = find_packet(q1, act_pkt);
				2: found_idx = find_packet(q2, act_pkt);
				3: found_idx = find_packet(q3, act_pkt);
			endcase

			if (found_idx != -1) begin
				case (port_id)
					0: q0.delete(found_idx);
					1: q1.delete(found_idx);
					2: q2.delete(found_idx);
					3: q3.delete(found_idx);
				endcase

				count_lock.get(1);
				match_count++;
				count_lock.put(1);

				$display(
					"[SCB] PASS: Match at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id, act_pkt.source, act_pkt.target, act_pkt.data
				);
			end
			else begin
				count_lock.get(1);
				mismatch_count++;
				count_lock.put(1);

				$display(
					"[SCB] FAIL: Unmatched packet at Port %0d (Src:%0d Target:%b Data:%h)",
					port_id, act_pkt.source, act_pkt.target, act_pkt.data
				);
			end
		end
	endtask

	function int find_packet(ref packet q[$], input packet p_in);
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

	function void dump_queue(int p);
		$display("      --- Expected Queue for Port %0d (First 5 items) ---", p);
		if (p == 0) print_q(q0);
		if (p == 1) print_q(q1);
		if (p == 2) print_q(q2);
		if (p == 3) print_q(q3);
		$display("      ---------------------------------------------------");
	endfunction

	function void print_q(ref packet q[$]);
		int limit;
		int i;

		limit = (q.size() > 5) ? 5 : q.size();
		if (q.size() == 0)
			$display("      [EMPTY]");

		for (i = 0; i < limit; i++) begin
			$display(
				"      [%0d] Exp Src=%0d Target=%b Data=%h",
				i, q[i].source, q[i].target, q[i].data
			);
		end
	endfunction

	function void report();
		int pending_count;
		int generated_count;
		int observed_count;
		int expected_destination_count;
		real coverage_pct;

		pending_count = q0.size() + q1.size() + q2.size() + q3.size();

		generated_count =
			generated_per_src[0] +
			generated_per_src[1] +
			generated_per_src[2] +
			generated_per_src[3];

		observed_count = match_count + mismatch_count;
		expected_destination_count = match_count + pending_count;

		// For this covergroup, VCS reports the aggregate source x destination
		// coverage through get_coverage(). A diagnostic run confirmed that
		// get_inst_coverage() returned 0.00% while get_coverage() returned 100%.
		coverage_pct = cov.cg_packet.get_coverage();

		$display("\n====================================================");
		$display("             STRICT SCOREBOARD REPORT               ");
		$display(" Generated input packets:          %0d", generated_count);
		$display(" Expected destination events:      %0d", expected_destination_count);
		$display(" Observed destination events:      %0d", observed_count);
		$display(" Matched destination events:       %0d", match_count);
		$display(" Unexpected/unmatched events:      %0d", mismatch_count);
		$display(" Missing expected events:          %0d", pending_count);
		$display(" Source x destination coverage:    %0.2f%%", coverage_pct);

		if (
			(generated_count > 0) &&
			(mismatch_count == 0) &&
			(pending_count == 0)
		)
			$display(" STATUS: PASSED");
		else
			$display(" STATUS: FAILED");

		$display("====================================================\n");

		if (pending_count != 0) begin
			dump_queue(0);
			dump_queue(1);
			dump_queue(2);
			dump_queue(3);
		end
	endfunction

endclass