interface WayInterface #(
    parameter COUNTER_WIDTH = 8,
  	parameter NUM_WAYS = 4,
  	parameter int DATA_WIDTH = 32,
  	parameter int BLOCK_SIZE = 32,
  	parameter int ADDRESS_WIDTH = 32
);
  
  localparam OFFSET_WIDTH = $clog2(BLOCK_SIZE);
  localparam TAG_WIDTH = ADDRESS_WIDTH - OFFSET_WIDTH;
  
  // -------------------------------------------
  // Signals 
  // -------------------------------------------
  
  // Metadata
  logic [ADDRESS_WIDTH - 1:0] 				address;// address from the memory
  logic [ADDRESS_WIDTH - 1:OFFSET_WIDTH] 	tag;	// tag to compare address
  logic 									valid;	// vaidity state
  logic 									dirty;
  
  // Age Tracking
  logic 						allocate;
  logic                        	accessed;
  logic [COUNTER_WIDTH - 1:0]  	accessedWayAge;
  logic [COUNTER_WIDTH - 1:0] 	myAge;
  logic                       	expired;
  
  // Data Management
  logic										wEn;	// write enable
  logic [DATA_WIDTH - 1:0]					dataIn;	// data coming in
  logic [DATA_WIDTH - 1:0]					dataOut;// data being read
  
  
  // -------------------------------------------
  // Modport definition
  // -------------------------------------------
  modport master ( // writes data
    input wEn,
    input dataIn
  );
  
  modport slave ( // for reading data
    output tag,
    output dataOut,
    output valid
  );
  
  modport evictionState (
    input accessed,
    input accessedWayAge,
    output dirty,
    output myAge,
    output expired
    
  );
  
    modport internal ( // Full access (for Way module itself)
    input  wEn, dataIn, accessed, address, allocate, accessedWayAge,
    output dataOut, tag, valid, myAge, expired
  );
  
endinterface : WayInterface