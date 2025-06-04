interface ControllerInterface #(
    parameter int	COUNTER_WIDTH 	= 8,
    parameter int	NUM_WAYS 		    = 4,
    parameter int DATA_WIDTH		  = 32, // bits
    parameter int BLOCK_SIZE 		  = 32, // bytes
    parameter int ADDRESS_WIDTH 	= 32
);

// -----------------------------------------
// From memory to cache
// -----------------------------------------
logic [8 * BLOCK_SIZE - 1:0]  fetchedData;    // Data fetched from main memory
logic [ADDRESS_WIDTH - 1:0]   fetchAddress; // Base address of fetched block


// -----------------------------------------
// From cache to memory
// -----------------------------------------
logic [8 * BLOCK_SIZE - 1:0]  writeBackData;  // Data to write back to main memory from dirt valid line
logic [ADDRESS_WIDTH - 1:0]   writeBackAddress;

// -----------------------------------------
// CPU to Cache
// -----------------------------------------
logic [ADDRESS_WIDTH - 1:0] cpuRequestAddress;
logic [DATA_WIDTH -1:0]     dataFromRegister; // to be written to cache

// -----------------------------------------
// Cache to CPU
// -----------------------------------------
logic [DATA_WIDTH -1:0]     dataToRegister; // to register



modport controller (
  input   cpuRequestAddress, dataFromRegister, fetchedData,
  output  dataToRegister, fetchAddress, writeBackData, writeBackAddress
);

modport memory (
  input   fetchAddress, writeBackAddress, writeBackData,
  output  fetchedData
);

modport cpu (
  input   dataToRegister,
  output  cpuRequestAddress, dataFromRegister
);


endinterface