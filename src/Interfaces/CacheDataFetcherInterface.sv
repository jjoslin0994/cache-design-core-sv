interface CacheDataFetcherInterface #(
	parameter int NUM_WAYS 		= 4,
  	parameter int DATA_WIDTH 	= 32
);
  
  logic [NUM_WAYS - 1:0] 	targetWay; 	// one-hot of way where desired data is held
  logic [DATA_WIDTH - 1:0] 	dataOut;	// data to be sent out
  
  modport master(
  	output 	targetWay, 	// master drives which data it wants
    input 	dataOut		// master recieves that data 
  );
  
  modport slave (
  	output 	dataOut,
    input 	targetWay
  );
  
endinterface
