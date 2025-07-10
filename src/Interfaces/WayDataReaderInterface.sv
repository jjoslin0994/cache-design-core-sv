interface WayDataReaderInterface #(
	parameter int NUM_WAYS 		  = 4,
  parameter int DATA_WIDTH 	  = 32,
  parameter int OFFSET_WIDTH  = 3,
);
  
  logic [NUM_WAYS - 1:0] 	    targetWay; 	// one-hot of way 
  logic [OFFSET_WIDTH - 1:0]  offset;
  logic [DATA_WIDTH - 1:0] 	  dataOut;	// data to be sent out
 
  
  modport master(
  	output 	targetWay, word_address 	// master drives which data it wants
    input 	dataOut		// master recieves that data 
  );
  
  modport slave (
  	output 	dataOut,
    input 	targetWay, word_address
  );
  
endinterface
