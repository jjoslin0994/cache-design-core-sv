
module LruEvictionPolicy #(
    parameter int NUM_WAYS = 512
)(
  input clk, reset_n,
  WayInterface.evictionState        wayIfs[NUM_WAYS],
  EvictionPolicyInterface.internal  evicPolicyIf
);

  localparam int COUNTER_WIDTH = $clog2(NUM_WAYS); 

  //------------------------------------------------------------
  //  Identify age of accessed way
  //------------------------------------------------------------
  logic [COUNTER_WIDTH - 1:0] ageLocalBuffer [NUM_WAYS];
  logic [COUNTER_WIDTH - 1:0] accessedWayAge;
  generate

    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].accessed = evicPolicy.hitWay[i];
      assign ageLocalBuffer[i] = (evicPolicy.hitWay[i]) ? wayIfs[i].myAge : '0;
    end

  endgenerate

  always_comb begin // OR together age buffer
    accessedWayAge = 0;
    for (int i = 0; i < NUM_WAYS; i++) begin
      accessedWayAge |= ageLocalBuffer[i];
    end
  end

  generate // generate signal propogate (fan-out to all ways)

    for (genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].accessedWayAge = accessedWayAge;
    end

  endgenerate

  // ----------------------------------------------------------
  // Prepare evicition target --- notify control module
  // ----------------------------------------------------------
  logic [NUM_WAYS - 1:0] evicitionTarget;

  generate
    for(genvar i = 0; i < NUM_WAYS; i++)begin
      assign evicitionTarget[i] = wayIfs[i].expired;
    end
  endgenerate

  always_comb begin

    evicPolicyIf.evictionTarget = evictionTarget;
    evicPolicyIf.evictionReady  = |(evicitionTarget);

  end

  endmodule

