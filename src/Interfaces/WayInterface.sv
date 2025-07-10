interface WayInterface #(
    parameter COUNTER_WIDTH = 8,
  	parameter NUM_WAYS = 4,
  	parameter int DATA_WIDTH = 32,
  	parameter int BLOCK_SIZE = 32,
  	parameter int ADDRESS_WIDTH = 32
);


  
  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     = $clog2(WORDS_PER_BLOCK);
  localparam int TAG_WIDTH        = ADDRESS_WIDTH - OFFSET_WIDTH;
  
  // -------------------------------------------
  // Signals 
  // -------------------------------------------
  
  // Metadata
  logic [ADDRESS_WIDTH - 1:0] 				    line_address;// line_address from the memory
  logic [ADDRESS_WIDTH - 1:OFFSET_WIDTH] 	tag;	  // tag to compare line_address
  logic 									                valid;	// vaidity state
  logic 									                dirty;
  logic [NUM_WAYS - 1:0]                  thisWay; // One-hot encode of this way
  
  // Age Tracking
  logic                         updateAge;
  logic 						            allocate;
  logic                        	accessed;
  logic [COUNTER_WIDTH - 1:0]  	accessedWayAge;
  logic [COUNTER_WIDTH - 1:0] 	myAge;
  logic                       	expired;
  
  // Data Management
  logic										                    wEn;	// write enable
  logic [DATA_WIDTH * WORDS_PER_BLOCK - 1:0]  fetched_line;
  logic [ADDRESS_WIDTH - 1:0]                 offset;
  logic [DATA_WIDTH - 1:0]					          dataIn;	// data coming in
  logic [DATA_WIDTH - 1:0]					          dataOut;// data being read
  
  
  // -------------------------------------------
  // Modport definition
  // -------------------------------------------
  modport write ( // writes data
    input wEn, tag, allocate, dataIn,// driven by EvictionAllocate
    output dataOut
  );
  
  modport master ( // for reading data
    output tag,
    output dataOut,
    output valid,
    output updateAge
  );
  
    modport read ( // for reading data
    output dataOut
  );
  
  modport evictionState (
    output  accessed,       // access flag
    output  accessedWayAge, // age of the accessed way
    input   dirty,          // this way has been written to 
    input   myAge,          // age of this way
    input   expired,        // this way is the LRU
    input   thisWay         // One-hot encoded
    
  );
  
  modport internal (
    input  wEn,
    input  dataIn,
    input  accessed,
    input  line_address,
    input  allocate,
    input  accessedWayAge,
    input  updateAge,
    input  write_address,
    input  read_address,
    output dataOut,
    output tag,
    output valid,
    output myAge,
    output expired,
    output dirty
  );

  
endinterface : WayInterface