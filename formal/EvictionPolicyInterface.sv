// EvictionPolicyInterface.sv
interface CacheEvictionInterface #(
    parameter int NUM_WAYS = 4,   // Adjusted to 4 for formal verification ease
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
    // Removed 'hit' as it's not used by LruEvictionPolicy
    // logic                    hit;
    // Removed 'missWay' and 'miss' as they're not used by LruEvictionPolicy
    // logic [NUM_WAYS - 1 : 0] missWay;
    // logic                    miss;
    logic [NUM_WAYS - 1 : 0] allocateWay;   // one-hot encoded
    // Removed 'allocate' as it's not used by LruEvictionPolicy
    // logic                    allocate;


// -------------------------------------------
// Outputs to Cache Controller
// -------------------------------------------
    logic [NUM_WAYS - 1 : 0] evictionTarget;
    logic                    evictionReady;      // indicates the target way found and is ready to be evicted


// --- MODPORT DEFINITIONS ---
// These define the 'views' or 'roles' for different modules connecting to this interface.

    // Modport for the LRU Policy module (like your LruEvictionPolicy)
    // It takes inputs from the controller and provides outputs to the controller.
    modport LruPolicy (
        input clk,
        input reset_n,
        input hitWay,
        input allocateWay,
        output evictionTarget,
        output evictionReady,
        // Tasks are listed by name only in modports:
        updateOnHit,
        updateOnAllocate,
        getEvictionTarget
    );

    // Modport for the Cache Controller module (the entity that *uses* the LRU Policy)
    // It provides inputs to the policy and receives outputs from it.
    modport Controller (
        output clk,
        output reset_n,
        output hitWay,
        output allocateWay,
        input evictionTarget,
        input evictionReady,
        // Tasks are listed by name only in modports:
        updateOnHit,
        updateOnAllocate,
        getEvictionTarget
    );

// -------------------------------------------
// Tasks and Functions (Definitions)
// -------------------------------------------

    // Task to be called by the cache controller when a cache line is hit.
    // The policy will update its internal recency/age state.
    task automatic updateOnHit(input logic [NUM_WAYS-1:0] hitWayIn); endtask // <-- This or next one is line 75

    // Task to be called by the cache controller when a new block is placed
    // into a cache line (i.e., allocated after a miss).
    // The policy will update its internal state to reflect the new entry.
    task automatic updateOnAllocate(input logic [NUM_WAYS-1:0] allocateWayIn); endtask

    // Task to be called by the cache controller when it needs an eviction candidate.
    // The policy will calculate and drive 'evictionTarget' and 'evictionReady'.
    // The cache controller would typically wait for 'evictionReady' to go high.
    task automatic getEvictionTarget(); endtask

endinterface : CacheEvictionInterface // This must be the very last line, correctly closing the interface