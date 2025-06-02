
module LruEvictionPolicy #(
    parameter int NUM_WAYS = 512
)(
    EvictionPolicyInterface policyIf,
	
	WayInterface.policy_side wayIfArray_out[NUM_WAYS]

);

    localparam int COUNTER_WIDTH = $clog2(NUM_WAYS); 

    // counter based LRU where MRU = 0 and LRU = NUM_WAYS - 1

	// logic [COUNTER_WIDTH - 1:0] wayAges [NUM_WAYS-1:0]; 
    logic [$clog2(NUM_WAYS)-1:0] accessedWayId; // for redundant check
    logic [COUNTER_WIDTH - 1:0] accessedWayAge;

  
  	
  WayInterface #(COUNTER_WIDTH, NUM_WAYS) wayIfArray[NUM_WAYS](); // array of way instances 

    //------------------------------------------------------------
    //  Intatiate Ways
    //------------------------------------------------------------
    generate
        genvar i;
        for (i = 0; i < NUM_WAYS; i++) begin : GenerateWays
          Way #(
            .NUM_WAYS(NUM_WAYS),
            .ID(i),
            .COUNTER_WIDTH(COUNTER_WIDTH)
          ) way_inst(
            .wayIf(wayIfArray[i]) // stor instance in array
          );
        end : GenerateWays
    endgenerate
 

    //------------------------------------------------------------
    //  Identify age to send back
    //------------------------------------------------------------
    always_comb begin : CalculateAccessedWayAge
        accessedWayAge = 0;
        accessedWayId = 0;

        for(int i = 0; i < NUM_WAYS; i++) begin
            if  (policyIf.hitWay[i] || policyIf.allocateWay[i]) begin  // traverse ways to identify first hit way (should only ever be one)
              accessedWayAge = wayIfArray[i].myAge;                           // set the value to send back to other ways
                accessedWayId = i;
                break;                                                 // only identify the one age
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

    // ----------------------------------------------------------------
    // Implementation of Interface Tasks
    // ----------------------------------------------------------------

    task automatic policyIf.updateOnHit(input logic [NUM_WAYS-1:0] hitWayIn); endtask // No-op task

    task automatic policyIf.updateOnAllocate(input logic [NUM_WAYS-1:0] allocateWayIn); endtask // No-op task

    




endmodule

