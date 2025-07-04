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
logic [ADDRESS_WIDTH - 1:0]   fetchAddress;   // Base address of fetched block


// -----------------------------------------
// From cache to memory
// -----------------------------------------
logic [8 * BLOCK_SIZE - 1:0]  writeBackData;    // Data to write back to main memory from dirt valid line
logic [ADDRESS_WIDTH - 1:0]   writeBackAddress;
logic                         writeBackAck;     // Ack storage of data

// -----------------------------------------
// CPU <--> Cache
// -----------------------------------------
logic                       request, read, write; // Control
logic [ADDRESS_WIDTH - 1:0] cpuRequestAddress;   // Adress requested by CPU
logic [DATA_WIDTH -1:0]     dataFromRegister;     // Write to Cache
logic [DATA_WIDTH - 1:0]    dataToRegister;       // Write to Registers





modport slave (
  input   request, cpuRequestAddress, dataFromRegister, fetchedData, read, write
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