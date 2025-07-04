/*
  Jonathan Joslin 6/29/25
  Write To Cache module writes mutated data from CPU registers back to cache line way
*/
module WriteToCache #(
  parameter int NUM_WAYS    = 4,
  parameter int DATA_WIDTH  = 32
)(
  WayInterface.write          wayIfs[NUM_WAYS],
  WriteToCacheInterface.slave writeToCacheIf
);

  generate
    
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].dataIn = {DATA_WIDTH{writeToCacheIf.targetWay[i] == 1'b1}} & writeToCacheIf.data;
      assign wayIfs[i].wEn = writeToCacheIf.targetWay[i] == 1'b1;
    end

  endgenerate

endmodule