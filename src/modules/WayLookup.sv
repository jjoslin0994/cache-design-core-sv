module WayLookup #(
  parameter int NUM_WAYS        = 4,
  parameter int ADDRESS_WIDTH   = 32,
  parameter int BLOCK_SIZE      = 32
) (
  input logic clk, reset_n, // global signals
  WayLookupInterface LookupIf,
  WayInterface.slave wayIfs[NUM_WAYS]
);
  

  logic [NUM_WAYS - 1:0] wayHits;
  
  generate
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayHits[i] = (wayIfs[i].valid===1'b1) && (wayIfs[i].tag == LookupIf.tag);      
    end
  endgenerate
  

  
  always_comb begin
    
    LookupIf.hitWay = wayHits; // one-hot encoding of the way.
    LookupIf.hit 	= |(wayHits);
    LookupIf.miss 	= ~(|wayHits);
    
  end

endmodule