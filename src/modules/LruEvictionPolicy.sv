
module LruEvictionPolicy #(
    parameter int NUM_WAYS = 512
)(
  logic clk, reset_n,
  WayInterface.evictionState        wayIfs[NUM_WAYS],
  WayLookupInterface.slave          wayLookupIf,
  EvictionPolicyInterface.internal  evicPolicyIf
);

  localparam int COUNTER_WIDTH = $clog2(NUM_WAYS); 

  // logic [COUNTER_WIDTH - 1:0] wayAges [NUM_WAYS-1:0]; 
  logic [$clog2(NUM_WAYS)-1:0]  accessedWayId; // for redundant check
  logic [COUNTER_WIDTH - 1:0]   accessedWayAge;

  //------------------------------------------------------------
  //  Identify age of accessed way
  //------------------------------------------------------------
  always_ff @(posedge clk or negedge reset_n) begin : FindAccessedWayAge
    if(!reset_n) begin
      for (int i = 0; i < NUM_WAYS; i++) begin
        wayIfs[i].accessed <= 0;
        wayIfs[i].accessedWayAge <= 0;
        accessedWayAge <= 0;
      end
    end else if(wayLookupIf.hit) begin
      for(int i = 0; i < NUM_WAYS; i++) begin
        if(wayLookupIf.hitWay == wayIfs[i].thisWay) begin
          wayIfs[i].accessed <= 1;
          accessedWayAge <= wayIfs[i].myAge;
        end
      end

      for(int i = 0; i < NUM_WAYS; i++) begin
        wayIfs[i].accessedWayAge <= accessedWayAge;
      end
    end else begin
      for (int i = 0; i < NUM_WAYS; i++) begin
        wayIfs[i].accessed <= 0;
        wayIfs[i].accessedWayAge <= 0;
      end
    end
  end

  always_comb begin : FindAccessedWayAge
    accessedWayAge  = 0;
    if(wayLookupIf.hit) begin
      for(int i = 0; i < NUM_WAYS; i++) begin
        if (wayLookupIf.hitWay[i]) begin  // traverse ways to identify first hit way (should only ever be one)
          accessedWayAge = wayIfs[i].myAge;              // set the value to send back to other ways
          accessedWayAgeReady = 1;
          wayIfs[i].accessed = 1;
          break;                                           // only identify the one age
        end
      end

      for(int i = 0; i < NUM_WAYS; i++) begin
        wayIfs[i].accessedWayAge = accessedWayAge;
      end
    end
  end

  // ----------------------------------------------------------
  // Prepare evicition target --- notify control module
  // ----------------------------------------------------------
  always_comb begin : getEvictionTarget
    evicPolicyIf.evictionTarget = '0;
    evicPolicyIf.evictionReady = 0;

    for (int i = 0; i < NUM_WAYS; i++) begin
      if(wayIfs[i].expired) begin
        evicPolicyIf.evictionTarget = 1'b1 << i;
        evicPolicyIf.evictionReady = 1;
        break;
      end
    end

  end : getEvictionTarget


endmodule

