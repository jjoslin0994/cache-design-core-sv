// cache Controller Top Design Module

module CacheController #(
  parameter int	COUNTER_WIDTH 	= 8,
  parameter int	NUM_WAYS 		= 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH 	= 32
)
  (
  input logic clk,
  input logic reset_n,
  WayInterface.master 			WayMasterIf,
  WayInterface.slave			WaySlaveIf,
  WayInterface.evictionState 	WayEvictionIf
);
  
  WayInterface WayIfs[NUM_WAYS]();
  
  //----------------------------------------------
  // Instantiate Eviction Policy
  //----------------------------------------------
  
  
  
  //----------------------------------------------
  // Instantiate Ways
  //----------------------------------------------
  
  genvar i;
  
  generate
    for (i = 0; i < NUM_WAYS; i++) begin : GenereateWays
      Way #(
        .NUM_WAYS(NUM_WAYS),
        .ID(i),
        .COUNTER_WIDTH($clog2(NUM_WAYS)),
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
        ) WayInst (
        .clk(clk)
        .reset_n(reset_n),
        .WayIf(WayIfs[i].internal)
      );  
    end : GenerateWays
  endgenerate
  
  
  
  
  
endmodule
