// Code your design here

interface EvictionPolicyInterface #(
    parameter int NUM_WAYS = 512,
    parameter int ADDRESS_WIDTH = 32
);

// ------------------------------------------
// Clock and Reset
// ------------------------------------------

    logic                   clk;        // clock
    logic                   reset_n;    // Active-low reset

// -------------------------------------------
// Cache Controller Inputs
// -------------------------------------------

    logic [NUM_WAYS - 1 : 0] hitWay;        // one-hot encoded
    logic                    hit;           // indicate cache hit
    logic [NUM_WAYS - 1 : 0] missWay;       // one-hot encoded
    logic                    miss;          // hit or miss
    logic [NUM_WAYS - 1 : 0] allocateWay;   // one-hot encoded
    logic                    allocate;      // indicates the target way is to be allocated



// -------------------------------------------
// Outputs to Cache Controller
// -------------------------------------------
    logic [NUM_WAYS - 1 : 0] evictionTarget;
    logic                    evictionReady;      // indicates the target way found and is ready to be evicted


// -------------------------------------------
// Tasks and Functions
// -------------------------------------------


    // Tasks: Declare without extern or import/export
    extern task updateOnHit(input logic [NUM_WAYS-1:0] hitWayIn);


    extern task updateOnAllocate(input logic [NUM_WAYS-1:0] allocateWayIn);
        // Default empty implementation, override in module
    

    extern task getEvictionTarget();
        // Default empty implementation, override in module
    

modport policyIf (
    input clk, reset_n, hitWay, hit, missWay, miss, allocateWay, allocate

    );


endinterface : EvictionPolicyInterface