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
  
  
  
  
  
endmodule
