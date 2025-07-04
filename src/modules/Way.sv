module Way #(
  	parameter int NUM_WAYS = 512,
    parameter int ID       = 0,
  	parameter int COUNTER_WIDTH = $clog2(NUM_WAYS),
  	parameter int DATA_WIDTH = 32,
  	parameter int BLOCK_SIZE = 32,
  	parameter int ADDRESS_WIDTH = 32
)(
  	logic 							clk,		// global clock
  	logic 							reset_n,	// global asynch reset
  
  	WayInterface.internal 			wayIf 		// Internal Interface
);
  
  
  	localparam OFFSET_WIDTH = 	$clog2(BLOCK_SIZE);
  	localparam TAG_WIDTH = 		ADDRESS_WIDTH - OFFSET_WIDTH;
  
  	// ------------------------------------------------
  	// Meta Data
	// ------------------------------------------------
  	
  	logic [TAG_WIDTH - 1:0] tag;
  	logic					          dirty;
  	logic 					        valid;

  
  	// ------------------------------------------------
  	// Data Storage
  	// ------------------------------------------------

  	logic [DATA_WIDTH - 1:0] 	data;
  
  always_ff@(posedge clk or negedge reset_n) begin : DataManagement
      if(!reset_n) begin
		    tag   <= '0;
        dirty <= 0;
        valid <= 0;
        data  <= '0;
        wayIf.thisWay = 1 << ID;
      end else if(wayIf.allocate) begin
          tag <= wayIf.address[ADDRESS_WIDTH - 1:OFFSET_WIDTH];
          dirty <= 	0;
          valid <= 	1;
      end else if (wayIf.wEn) begin
      	  data <= 	wayIf.dataIn;
          dirty <= 	1;
      end
  	end : DataManagement
  

  	assign wayIf.dataOut = data; 
  
  
  
  	// --------------------------------------------------
  	// Eviction Logic
  	// Instantiate Age Tracker
  	// --------------------------------------------------
    WayAgeTracker #(
      .NUM_WAYS(NUM_WAYS),
      .ID(ID),
      .COUNTER_WIDTH($clog2(NUM_WAYS))
    ) AgeTracker (
      .clk(clk),
      .reset_n(reset_n),
      .accessedWayAge(wayIf.accessedWayAge),
      .accessed(wayIf.accessed),
      .myAge(wayIf.myAge),
      .expired(wayIf.expired)
    );

endmodule

module WayAgeTracker #(
	  parameter int NUM_WAYS = 512,
    parameter int ID       = 0,
  	parameter int COUNTER_WIDTH = $clog2(NUM_WAYS)
) (
  	input logic 						            clk,
	  input logic 						            reset_n,
  	input logic [COUNTER_WIDTH - 1:0] 	accessedWayAge,
  	input logic 						            accessed,
  	output logic [COUNTER_WIDTH - 1:0]	myAge,
  	output logic 						            expired,
);
  
  logic [COUNTER_WIDTH - 1:0] age;
  
  assign expired = (age == NUM_WAYS - 1);
  assign myAge = age;
  
  always_ff @(posedge clk or negedge reset_n) begin : AgeCounter
    if (!reset_n) begin
      age <= ID;
    end else if (wayIf.updateAge) begin 
      if (accessed && (myAge == accessedWayAge)) begin
        age <= 0;
      end else if (age < accessedWayAge) begin
        age <= age + 1;
      end
    end
  end

 
endmodule