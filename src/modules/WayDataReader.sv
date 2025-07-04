// Code your design here
module WayDataReader #(
  parameter int NUM_WAYS    = 512,
  parameter int DATA_WIDTH	= 32
)(
  WayInterface.slave wayIfs[NUM_WAYS],
  WayDataReaderInterface.read wayDataReaderIf
);

/*
  Upon hit get data from cache to return to CPU
*/

  logic [DATA_WIDTH - 1:0] readData;
  logic [DATA_WIDTH - 1:0] dataLocalBuffer [NUM_WAYS];
  generate // creat local copy of way data and zeros 
  
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign dataLocalBuffer[i] = (wayDataReaderIf.targetWay[i] === 1'b1) ? wayIfs[i].dataOut : '0;
    end

  endgenerate

  always_comb begin // or together data 
    readData = 0;
    for (int i = 0; i < NUM_WAYS; i++) begin
      readData |= dataLocalBuffer[i];
    end
  end

  always_comb begin // send back prepared data
    wayDataReaderIf.dataOut = readData;
  end

endmodule