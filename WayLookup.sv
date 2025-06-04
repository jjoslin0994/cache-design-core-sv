module WayLookup #(
  parameter int NUM_WAYS        = 4,
  parameter int ADDRESS_WIDTH   = 32,
  parameter int BLOCK_SIZE      = 32
) (
  input clk, reset_n, // global signals
  WayLookupInterface LookupIf,
  WayInterface.slave wayIfs[NUM_WAYS]
);
  

  always_comb begin : MatchTag
    LookupIf.hitWay = '0;
    LookupIf.hit 	= 0;
    LookupIf.miss 	= 0;
    
    for(int i = 0; i < NUM_WAYS; i++) begin
      if(wayIfs[i].valid && wayIfs[i].tag == LookupIf.tag) begin
        LookupIf.hitWay = 1 << i; // one-hot encoding
        LookupIf.hit = 1;
        break;
      end
    end
    
	LookupIf.miss = ~LookupIf.hit;
  end : MatchTag

endmodule