// cache Controller Top Design Module

module CacheController #(
  parameter int	COUNTER_WIDTH 	= 8,
  parameter int	NUM_WAYS 		= 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH 	= 32
)
  (
    input logic 			      clk, reset_n, // global signals 

    // Interfaces passed in from testbench
    ControllerInterface 	  controllerIf,
    WayInterface 			      wayIfs[NUM_WAYS],
    WayLookupInterface		  wayLookupIf,
    EvictionPolicyInterface evicPolicyIf
  );
  
  
  //----------------------------------------------
  // Instantiate Eviction Policy
  //----------------------------------------------
  LruEvictionPolicy #(
    .NUM_WAYS(NUM_WAYS)
  ) LruPolicyInst(
    .clk(clk),
    .reset_n(reset_n),
    .wayIfs(wayIfs),
    .wayLookupIf(wayLookupIf),
    .evicPolicyIf(evicPolicyIf)
  );
  
  
  //----------------------------------------------
  // Instantiate Ways
  //----------------------------------------------
  
  genvar i;
  
  generate
    for (i = 0; i < NUM_WAYS; i++) begin : GenerateWays
      Way #(
        .NUM_WAYS(NUM_WAYS),
        .ID(i),
        .COUNTER_WIDTH($clog2(NUM_WAYS)),
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
        ) WayInst (
        .clk(clk),
        .reset_n(reset_n),
        .wayIfs(wayIfs[i].internal)
      );  
    end : GenerateWays
  endgenerate
  
  //----------------------------------------------
  // Instantiate Lookup Module
  //----------------------------------------------
  WayLookup #(
    .NUM_WAYS(NUM_WAYS),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
  ) lookupInst (
    .clk(clk),
    .reset_n(reset_n),
    .LookupIf(wayLookupIf),
    .wayIfs(wayIfs[i])
  );

  // -------------------------------------------------------
  // Flow Cotrol FSM
  // -------------------------------------------------------

  localparam IDLE     = 3'd0; // Wait for CPU request
  localparam LOOKUP   = 3'd1; // Compare tags of ways
  localparam HIT      = 3'd2; // If hit send data to CPU
  localparam MISS     = 3'd3; // Handle Miss (Get eviction target from Policy Module) request data from Main Mem
  localparam ALLOCATE = 3'd4; // Overwrite way marked for eviction 

  logic [2:0] controlState;

  always_ff @(posedge clk or negedge reset_n) begin : CacheFlowControl
    if(!reset_n) begin
      controlSate <= IDLE;
    end
    else begin
      case (controlSate)
        IDLE : begin
          if(controllerIf.request)begin
            controlSate <= LOOKUP;
          end
        end

        LOOKUP : begin

        end

        HIT : begin

        end

        MISS : begin

        end

        ALLOCATE : begin

        end

        default: controlState <= IDLE;
      endcase

    end

  end
  
  
  
  
  
endmodule
