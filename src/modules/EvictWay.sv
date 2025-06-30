module EvictAndAllocateWay #(
  parameter int NUM_WAYS        = 4,
  parameter int ADDRESS_WIDTH   = 32,
  parameter int BLOCK_SIZE      = 32
)(
  input logic clk,reset_n,

  EvictionInterface.slave evictionIf,
  WayInterface.write wayIfs[NUM_WAYS]
);



  generate
    for(genvar i = 0; i < NUM_WAYS; i++) begin
        assign wayIfs[i].dataIn = (wayIfs[i].allocate === 1'b1) 
                && (evictionIf.target[i] === 1'b1) 
                && (wayIfs[i].wEn === 1'b1) 
                ? evictionIf.dataIn : 0;
    end
  endgenerate


endmodule

