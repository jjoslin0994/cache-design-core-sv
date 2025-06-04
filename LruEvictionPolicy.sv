
module LruEvictionPolicy #(
    parameter int NUM_WAYS = 512
)(
    EvictionPolicyInterface.internal EvicIf
	WayInterface.evictionState wayIfs[NUM_WAYS]
);

    localparam int COUNTER_WIDTH = $clog2(NUM_WAYS); 

    // counter based LRU where MRU = 0 and LRU = NUM_WAYS - 1

	// logic [COUNTER_WIDTH - 1:0] wayAges [NUM_WAYS-1:0]; 
    logic [$clog2(NUM_WAYS)-1:0] accessedWayId; // for redundant check
    logic [COUNTER_WIDTH - 1:0] accessedWayAge; 

    //------------------------------------------------------------
    //  Identify age to send back
    //------------------------------------------------------------
    always_comb begin : CalculateAccessedWayAge
        accessedWayAge = 0;
        accessedWayId = 0;

        for(int i = 0; i < NUM_WAYS; i++) begin
          if  (EvicIf.hitWay[i] || EvicIf.allocateWay[i]) begin  // traverse ways to identify first hit way (should only ever be one)
              accessedWayAge = wayIfArray[i].myAge;              // set the value to send back to other ways
                accessedWayId = i;
                break;                                           // only identify the one age
            end
        end
    end
  
  	// ----------------------------------------------------------
  	// Prepare evicition target --- notify control module
  	// ----------------------------------------------------------
  
    always_comb begin : getEvictionTarget
      policyIf.evictionTarget = '0;
      policyIf.evictionReady = 0;

      for (int i = 0; i < NUM_WAYS; i++) begin
        if(wayIfArray[i].expired) begin
          policyIf.evictionTarget = 1'b1 << i;
          break;
        end
      end

      if(policyIf.evictionTarget != '0) begin
        policyIf.evictionReady = 1;
      end

    end : getEvictionTarget


endmodule

