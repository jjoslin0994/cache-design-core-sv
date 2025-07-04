interface WriteBackInterface #(
  parameter int	COUNTER_WIDTH = 8,
  parameter int	NUM_WAYS 		  = 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH = 32
);

  // ----------------------------------------------
  // Control Signals
  // ----------------------------------------------
  logic ack;            // Memory Acknowledgement of reception
  logic waitingForAck;  // Flag to protect buffres if waiting on last write ack
  logic readyToSend;           // next write is ready to be read by memeory for witeback
  logic request;        // Controller is requesting to writeback to main memory

  // ----------------------------------------------
  // Data Signals 
  // ----------------------------------------------
  logic [DATA_WIDTH - 1:0]    dataIn;     // Data to be loaded into wirteback buffer
  logic [DATA_WIDTH - 1:0]    dataOut;    // Data to main memory from writeback buffer
  logic [ADDRESS_WIDTH - 1:0] w_address;  // Block address of cache line to be written back


  modport master (
    input waitingForAck, readyToSend, dataOut, w_address,
    output request, ack, dataIn
  );

  modport slave (
    input request, ack, dataIn,
    output waitingForAck, readyToSend, dataOut, w_address
  );

endinterface