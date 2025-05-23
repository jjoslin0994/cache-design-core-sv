
interface CacheEvictionInterface #(
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


    // Task to be called by the cache controller when a cache line is hit.
    // The policy will update its internal recency/age state.
    task automatic updateOnHit(input logic [NUM_WAYS-1:0] hitWayIn); endtask
        // Implementation will be in the actual policy modules (LRU, FIFO, etc.)


    // Task to be called by the cache controller when a new block is placed
    // into a cache line (i.e., allocated after a miss).
    // The policy will update its internal state to reflect the new entry.
    task automatic updateOnAllocate(input logic [NUM_WAYS-1:0] allocateWayIn); endtask
        // Implementation will be in the actual policy modules

    // Task to be called by the cache controller when it needs an eviction candidate.
    // The policy will calculate and drive 'evictionTarget' and 'evictionReady'.
    // The cache controller would typically wait for 'evictionReady' to go high.
    task automatic getEvictionTarget(); endtask
        // Implementation will be in the actual policy modules


endinterface : CacheEvictionInterface