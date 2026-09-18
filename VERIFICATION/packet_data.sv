`ifndef PACKET_DATA_SV
`define PACKET_DATA_SV

typedef enum {SINGLE, MULTICAST, BROADCAST} pkt_type_e;

class packet;
	//Metadata 
	string name;
	int id;
	static int pkt_count = 0; 

	//Fields
	bit [3:0] source; 
	
	rand bit [3:0] target; 
	rand bit [7:0] data;   
	rand pkt_type_e p_type; 

	
	rand bit loopback_en; 

	//Constructor 
	function new(string name = "packet", int port_id = 0);
		this.name = name;
		this.id = pkt_count++; 
		this.source = 1 << port_id;
	endfunction

	//Constraints

	//Target Validation
	constraint valid_target {
		target != 4'b0000; 
	}

	//Loopback Distribution
	
	constraint c_loopback_dist {
		loopback_en dist { 0 := 90, 1 := 10 };
	}

	
	constraint c_loopback_logic {
		if (loopback_en == 0) {
			(source & target) == 0; 
		} else {
			(source & target) != 0; 
		}
	}

	//Packet Type Consistency
	constraint type_consistency {
		(p_type == SINGLE)    -> ($countones(target) == 1);
		(p_type == MULTICAST) -> ($countones(target) inside {2, 3});
		(p_type == BROADCAST) -> (target == 4'b1111);
	}

	//Packet Type Distribution
	constraint type_dist {
		p_type dist {SINGLE := 70, MULTICAST := 20, BROADCAST := 10};
	}

	//Data Pattern Distribution 
	constraint data_dist {
		data dist { 
			[0:85]    := 1, 
			[86:170]  := 1, 
			[171:255] := 1  
		};
	}

	//Methods 
	function pkt_type_e get_type();
		return p_type;
	endfunction

	virtual function void print();
		$display("------------------------------------------------");
		$display(" Packet ID: %0d | Name: %s", id, name);
		$display(" Type:      %s", p_type.name());
		$display(" Source:    %b (One-Hot)", source);
		$display(" Target:    %b (Mask)", target);
		$display(" Data:      0x%h", data);
		$display("------------------------------------------------");
	endfunction

	virtual function bit compare(packet other);
		if (this.source == other.source && 
			this.target == other.target && 
			this.data == other.data)
			return 1;
		else
			return 0;
	endfunction

	virtual function packet clone();
		packet p = new(this.name);
		p.source = this.source;
		p.target = this.target;
		p.data   = this.data;     
		p.p_type = this.p_type;
		p.id     = this.id; 
		return p;
	endfunction

endclass

// --- Derived Classes ---

class single_packet extends packet;
	function new(string name="single", int port_id=0);
		super.new(name, port_id);
	endfunction
	constraint force_type { p_type == SINGLE; }
endclass

class multicast_packet extends packet;
	function new(string name="multicast", int port_id=0);
		super.new(name, port_id);
	endfunction
	constraint force_type { p_type == MULTICAST; }
	
endclass

class broadcast_packet extends packet;
	function new(string name="broadcast", int port_id=0);
		super.new(name, port_id);
	endfunction
	constraint force_type { p_type == BROADCAST; }
	constraint allow_loopback_bits { target == 4'b1111; }
endclass

`endif