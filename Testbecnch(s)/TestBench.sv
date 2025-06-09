class CacheDesignTest;
  localparam int NUM_WAYS = 4;
  rand bit [NUM_WAYS-1:0] hitWay;
  rand bit [NUM_WAYS-1:0] allocateWay;
  
  constraint one_hot_hit { $countones(hitWay) <= 1;} // hitWay can only have one high bit
  
  constraint one_hot_allocate { $countones(allocateWay) <= 1; }
  
  constraint allocate_hit_mutual_exclusion { !(hitWay & allocateWay); }
  
endclass

module testbench;
  
  logic clk = 0;
  logic reset_n = 1;
  
  // -----------------------------------------------
  // Instantiate Controller Interface
  // -----------------------------------------------
  ControllerInterface #(
    .COUNTER_WIDTH	(8),
    .NUM_WAYS		(4),
    .DATA_WIDTH		(32),
    .BLOCK_SIZE		(32),
    .ADDRESS_WIDTH	(32)
  ) controllerIfInst();
  // -----------------------------------------------
  // Instantiate array of WayInterface(s)
  // -----------------------------------------------
  WayInterface #(
    .COUTNER_WIDTH(8),
    .NUM_WAYS(4),
    .DATA_WIDTH(32),
    .BLOCK_SIZE(32),
    .ADDRESS_WIDTH(32)
  ) wayIfs[NUM_WAYS]();
 
  // -----------------------------------------------
  // Instantiate WayLookup Interface
  // -----------------------------------------------
  WayLookupInterface #(
    parameter int NUM_WAYS = 4,
    parameter int ADDRESS_WIDTH = 32, 
    parameter int BLOCK_SIZE = 32
  ) wayLookupIfInst();
  
  
  // -----------------------------------------------
  // Instantiate EvictionPolicy Interface
  // -----------------------------------------------
  EvictionPolicyInterface #(
    .NUM_WAYS(4),
    .ADDRESS_WIDTH(32)
  ) evictionPolicyIfInst();
  
  
  // ---------------------------------------------------
  // Instantiate CacheController (Top Design Module)
  // ---------------------------------------------------
  CacheController #(
    .COUNTER_WIDTH(8),
    .NUM_WAYS(4),
    .DATA_WIDTH(32),
    .BLOCK_SIZE(32),
    .ADDRESS_WIDTH(32))
  cacheControllerInst (
    .clk(clk),
    .reset_n(reset_n),
    .controllerIf(controllerIfInst),
    .wayIfs(wayIfs),
    .wayLookupIf(wayLookupIfInst),
    .evicPolicyIf(evictionPolicyIfInst)
  );
  
   always #5 clk = ~clk;

  initial begin
    CacheEvictionTest test;
    test = new();
      
    // -----------------------------------------------
    // Trigger Active Low reset_n
    // -----------------------------------------------
      reset_n = 0;
    #5;
    reset_n = 1;
    #5;

   

    // --------------------------------------------------------------------
    // Test Age propogation
    // --------------------------------------------------------------------




  	$finish;  // <--- valid here
  end

 
  
endmodule
