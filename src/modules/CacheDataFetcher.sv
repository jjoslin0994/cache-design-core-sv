// Code your design here
module CacheDataFetcher #(
  parameter int NUM_WAYS    = 512,
  parameter int DATA_WIDTH	= 32
)(
  WayInterface.slave wayIfs[NUM_WAYS],
  CacheDataFetcherInterface.slave CacheDataFetcherIf
);

/*
  Upon hit get data from cache to return to CPU
*/

  logic [DATA_WIDTH - 1:0] fetchedData;
  logic [DATA_WIDTH - 1:0] dataLocalBuffer [NUM_WAYS];
  generate // creat local copy of way data and zeros 
  
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign dataLocalBuffer[i] = (CacheDataFetcherIf.targetWay[i] === 1'b1) ? wayIfs[i].dataOut : '0;
    end

  endgenerate

  always_comb begin // or together data 
    fetchedData = 0;
    for (int i = 0; i < NUM_WAYS; i++) begin
      fetchedData |= dataLocalBuffer[i];
    end
  end

  always_comb begin // send back prepared data
    CacheDataFetcherIf.dataOut = fetchedData;
  end

endmodule