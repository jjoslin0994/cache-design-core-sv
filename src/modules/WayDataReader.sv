// Code your design here
module WayDataReader #(
  parameter int NUM_WAYS    = 512,
  parameter int DATA_WIDTH	= 32, 
  parameter int ADDRESS_WIDTH = 32,

)(
  WayInterface.slave wayIfs[NUM_WAYS],
  WayDataReaderInterface.read wayDataReaderIf
);

/*
  Upon hit get data from cache to return to CPU
*/

  logic [DATA_WIDTH - 1:0] readData;
  logic [DATA_WIDTH - 1:0] data_buffer [NUM_WAYS];

  generate // propogate offset from controller to ways
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].offset = wayDataReaderIf.offset;
    end
  endgenerate

  generate // creat local copy of way data and zeros 
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign data_buffer[i] = (wayDataReaderIf.targetWay[i] === 1'b1) ? wayIfs[i].dataOut : '0;
    end
  endgenerate

  always_comb begin // or together data 
    readData = 0;
    for (int i = 0; i < NUM_WAYS; i++) begin
      readData |= data_buffer[i];
    end
  end

  always_comb begin // send back prepared data
    wayDataReaderIf.dataOut = readData;
  end

endmodule