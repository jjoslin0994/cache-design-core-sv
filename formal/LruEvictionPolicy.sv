// reworked for formal verification

module LruEvictionPolicy #(
    parameter int NUM_WAYS = 4,
    parameter int COUNTER_WIDTH = $clog2(NUM_WAYS)
)(
    input  logic                 clk,
    input  logic                 reset_n,
    input  logic [NUM_WAYS-1:0] hitWay,
    input  logic [NUM_WAYS-1:0] allocateWay,

    output logic [NUM_WAYS-1:0] evictionTarget,
    output logic                evictionReady,
    
);

    
    logic [NUM_WAYS-1:0] expirationFlags;

    logic [COUNTER_WIDTH-1:0] accessedWayAge;
    logic [$clog2(NUM_WAYS)-1:0] accessedWayId;

    genvar i;
    generate
        for(i=0; i<NUM_WAYS; i++) begin : ways
            Way #(
                .NUM_WAYS(NUM_WAYS),
                .ID(i),
                .COUNTER_WIDTH(COUNTER_WIDTH)
            ) lru_way_inst (
                .clk(clk),
                .reset_n(reset_n),
                .accessed(hitWay[i] | allocateWay[i]),
                .accessedWayId(accessedWayId),
                .accessedWayAge(accessedWayAge),
                .myAge(wayAges[i]),
                .expired(expirationFlags[i])
            );
        end
    endgenerate

    // Flatten wayAges for output port
    // always_comb begin
    //     for(int j=0; j<NUM_WAYS; j++) begin
    //         wayAges_flat[ (j+1)*COUNTER_WIDTH -1 -: COUNTER_WIDTH ] = wayAges[j];
    //     end
    // end

    //------------------------------------------------------------
    //  Identify age to send back
    //------------------------------------------------------------
    logic found_accessed;
    // CalculateAccessedWayAge
    always_comb begin : CalculateAccessedWayAge
        accessedWayAge = 0;
        accessedWayId  = 0;
        found_accessed = 0;

        for (int i = 0; i < NUM_WAYS; i++) begin
            if (!found_accessed && (hitWay[i] || allocateWay[i])) begin
                accessedWayAge = wayAges[i];
                accessedWayId  = i;
                found_accessed = 1;
            end
        end
    end


    logic found_eviction;
    //------------------------------------------------------------
    //  Identify Eviction Target and notify controller
    //------------------------------------------------------------
    always_comb begin
        evictionTarget = '0;
        evictionReady  = 0;
        found_eviction = 0;

        for (int i = 0; i < NUM_WAYS; i++) begin
            if (!found_eviction && expirationFlags[i]) begin
                evictionTarget = 1'b1 << i;
                evictionReady  = 1'b1;
                found_eviction = 1;
            end
        end
    end


endmodule


module Way #(
    parameter int NUM_WAYS = 512,
    parameter int ID       = 0,
    parameter int COUNTER_WIDTH
)(
    input logic                         clk,            // CPU clock
    input logic                         reset_n,        // if the way is hit rest the counter
    input logic                         accessed,       // High when this way is hit
    input logic [COUNTER_WIDTH - 1:0]   accessedWayAge, // age of the way that was accessed
    input logic [$clog2(NUM_WAYS) - 1:0]   accessedWayId,  // redundant check of accessed way ID
    
    output logic [COUNTER_WIDTH - 1:0]  myAge,          // broadcast age to controller to compare to accessed way's age
    output logic expired                                // Flag indicating this way has expired and need ready to be evicted
);


    logic [COUNTER_WIDTH - 1:0] age;

    assign expired = age == (NUM_WAYS - 1);
    assign myAge = age;



    always_ff @(posedge clk or negedge reset_n) begin 

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

    end 

endmodule