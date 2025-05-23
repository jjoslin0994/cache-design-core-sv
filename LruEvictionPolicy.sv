
module LruEvictionPolicy (
    CacheEvictionInterface.LruPolicy policyIf
);

    // Get parameters from the interface instance
    localparam int NUM_WAYS = policyIf.NUM_WAYS;
    localparam int COUNTER_WIDTH = $clog2(NUM_WAYS); 

    // counter based LRU where MRU = 0 and LRU = NUM_WAYS - 1

    logic [COUNTER_WIDTH - 1:0] wayAges [NUM_WAYS-1:0]; 
    logic [$clog2(NUM_WAYS)-1:0] accessedWayId; // for redundant check
    logic [COUNTER_WIDTH - 1:0] accessedWayAge;
    logic expirationFlags [NUM_WAYS - 1:0];

    //------------------------------------------------------------
    //  Intatiate Ways
    //------------------------------------------------------------
    generate : GenerateWays
        for(genvar i = 0; i < NUM_WAYS; i++) begin
            Way #(
                .NUM_WAYS(NUM_WAYS),            // Pass number of ways
                .ID       (i),                  // pass unique ID to each instance
                .COUNTER_WIDTH(COUNTER_WIDTH)   // Pass width of age counter
            ) lru_way_inst (
                // inputs---------------------------------------------
                .clk     (policyIf.clk),                // cpu clock
                .reset_n (policyIf.reset_n),            // global sync reset
                .accessed(policyIf.hitWay[i] 
                        | policyIf.allocateWay[i]),     // way was accessed or allocated
                .accessedWayId(accessedWayId),          // add robustness to multiple ways claiming access. 
                .accessedWayAge(accessedWayAge),        // age of the way that was accessed 
                // outputs -------------------------------------------
                .myAge   (wayAges[i]),                  // age of this way
                .expired (expirationFlags[i])           // flag of expired way
            );
        end
    endgenerate : GenerateWays

    //------------------------------------------------------------
    //  Identify age to send back
    //------------------------------------------------------------
    always_comb begin : CalculateAccessedWayAge
        accessedWayAge = 0;
        accessedWayId = 0;

        for(int i = 0; i < NUM_WAYS; i++) begin
            if  (policyIf.hitWay[i] || policyIf.allocateWay[i]) begin  // traverse ways to identify first hit way (should only ever be one)
                accessedWayAge = wayAges[i];                           // set the value to send back to other ways
                accessedWayId = i;
                break;                                                 // only identify the one age
            end
        end
    end

    // ----------------------------------------------------------------
    // Implementation of Interface Tasks
    // ----------------------------------------------------------------

    task automatic policyIf.updateOnHit(input logic [NUM_WAYS-1:0] hitWayIn); endtask // No-op task

    task automatic policyIf.updateOnAllocate(input logic [NUM_WAYS-1:0] allocateWayIn); endtask // No-op task

    task automatic policyIf.getEvictionTarget();
        policyIf.evictionTarget = '0; // initally target nothing
        for (int i = 0; i < NUM_WAYS; i++) begin
            if (expirationFlags[i]) begin
                policyIf.evictionTarget = 1'b1 << i; // one-hot encoded bit position of way
                break;
            end
            
        end

        policyIf.evictionReady = 1'b1; // raise eviction ready flag
    
    endtask

endmodule

module Way #(
    parameter int NUM_WAYS = 512;
    parameter int ID       = 0;
    parameter int COUNTER_WIDTH;
)(
    input logic                         clk,            // CPU clock
    input logic                         reset_n,        // if the way is hit rest the counter
    input logic                         accessed,       // High when this way is hit
    input logic [COUNTER_WIDTH - 1:0]   accessedWayAge, // age of the way that was accessed
    input logic [COUNTER_WIDTH - 1:0]   accessedWayId,  // redundant check of accessed way ID
    
    output logic [COUNTER_WIDTH - 1:0]  myAge,          // broadcast age to controller to compare to accessed way's age
    output logic expired                                // Flag indicating this way has expired and need ready to be evicted
);


    logic [COUNTER_WIDTH - 1:0] age;

    assign expired = age == (NUM_WAYS - 1);
    assign myAge = age;



    always_ff @(posedge clk or negedge reset_n) begin AgeCounter

        if(!reset_n) begin
            // on reset, init to unique age based on ID for well ordering of ways in LRU
            age <= ID;
        end 
        else if (accessed && ID == accessedWayId) begin
            age <= 0; // back to MRU
        end
        else if(age < accessedWayAge) begin
            age <= age + 1;
        end


    end : AgeCounter

endmodule