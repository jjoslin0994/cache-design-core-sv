// Code your design here

interface EvictionPolicyInterface #(
  parameter int NUM_WAYS = 512,
);

// ------------------------------------------
// Clock and Reset -- Passed as global signals
// ------------------------------------------


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
// Modports
// -------------------------------------------

  modport evictionPolicyMaster (
    input evictionTarget,
    input evictionReady,
    output hitWay,
    output hit,
    output missWay,
    output miss,
    output allocateWay,
    output allocate
  );
    modport evictionPolicySlave (
    input hitWay,
    input hit,
    input missWay,
    input miss,
    input allocateWay,
    input allocate,
    output evictionTarget,
    output evictionReady
  );
  modport internal (
    input hitWay, hit, missWay, miss, allocateWay, allocate
  );
      



endinterface : EvictionPolicyInterface