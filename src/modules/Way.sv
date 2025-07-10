module Way #(
  	parameter int NUM_WAYS      = 512,
    parameter int ID            = 0,
  	parameter int COUNTER_WIDTH = $clog2(NUM_WAYS),
  	parameter int DATA_WIDTH    = 32,
  	parameter int BLOCK_SIZE    = 32,
  	parameter int ADDRESS_WIDTH = 32
)(
  	logic 							  clk,		// global clock
  	logic 							  reset_n,	// global asynch reset
  
  	WayInterface.internal wayIf 		// Internal Interface
);
  
  
  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     = $clog2(WORDS_PER_BLOCK);
  localparam int TAG_WIDTH        = ADDRESS_WIDTH - OFFSET_WIDTH;

  // ------------------------------------------------
  // Meta Data
	// ------------------------------------------------
  
  logic [TAG_WIDTH - 1:0] tag;
  logic					          dirty;
  logic 					        valid;


  // ------------------------------------------------
  // Data Storage
  // ------------------------------------------------
  logic [DATA_WIDTH - 1:0] cache_line_array [WORDS_PER_BLOCK];

  // ---------------------------------------------------
  // Way Control logic
  // ---------------------------------------------------
  always_ff@(posedge clk or negedge reset_n) begin 
    if(!reset_n) begin
      tag           <= '0;
      valid         <= 0;
    end else if(wayIf.allocate) begin
        tag <= wayIf.line_address[ADDRESS_WIDTH - 1:OFFSET_WIDTH];
        valid <= 	1;
    end
  end

  // ------------------------------------------------------
  // Way Allcocate and Write
  // ------------------------------------------------------
  always_ff @ (posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      dirty     <= 0;
      for(int i = 0; i < WORDS_PER_BLOCK; i++) begin
        cache_line_array[i] <= '0;
      end

    end else if(wayIf.allocate) begin
      for(int i = 0; i < WORDS_PER_BLOCK; i++) begin
        cache_line_array[i] <= wayIf.fetched_line[i * DATA_WIDTH +: DATA_WIDTH];
      end
      dirty <= 1;
    end else if(wayIf.w_en) begin
      cache_line_array[wayIf.offset] <= wayIf.dataIn;
      dirty <= 1;
    end
  end

  // --------------------------------------------------
  // Read
  // --------------------------------------------------
  always_comb begin
    wayIf.dataOut = cache_line_array[wayIf.offset];
  end
  
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
    .wayIf(wayIf)
  );

endmodule

module WayAgeTracker #(
	  parameter int NUM_WAYS = 512,
    parameter int ID       = 0,
  	parameter int COUNTER_WIDTH = $clog2(NUM_WAYS)
) (
  	input logic 					clk,
	  input logic 					reset_n,
    WayInterface.internal wayIf
);
  
  logic [COUNTER_WIDTH - 1:0] age;
  
  
  assign wayIf.expired = (age == NUM_WAYS - 1);
  assign wayIf.myAge = age;
  
  always_ff @(posedge clk or negedge reset_n) begin : AgeCounter
    if (!reset_n) begin
      age <= ID;
    end else if (wayIf.updateAge) begin 
      if (wayIf.accessed && (age == wayIf.accessedWayAge)) begin
        age <= 0;
      end else if (age < wayIf.accessedWayAge) begin
        age <= age + 1;
      end
    end
  end

 
endmodule