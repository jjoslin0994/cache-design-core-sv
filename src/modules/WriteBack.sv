module WriteBack #(
  parameter int	COUNTER_WIDTH = 8,
  parameter int	NUM_WAYS 		  = 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH = 32
) (
  logic clk, reset_n,
  EvictionPolicyInterface.master  evicPolicyIf,
  WayInterface.master             wayIfs[NUM_WAYS],
  WriteBackInterface.slave        wbIf
);

// We assume that the ack line from memory has already been synchronized.

// output wating for ack signal to controller to stall ctroll FSM if buffer is full

  logic waitingForAck; // Lets us know main memoryrecieved the data

  assign wbIf.waitingForAck = waitingForAck;


  logic [DATA_WIDTH - 1:0]    writeBackDataBuffer;
  logic [ADDRESS_WIDTH - 1:0] writeBackAddressBuffer;
  logic [TAG_WIDTH - 1:0]     writeBackTag[NUM_WAYS];
  logic [TAG_WIDTH - 1:0]     nextWriteBackTagBuffer[NUM_WAYS];
  logic [TAG_WIDTH - 1:0]     nextWriteBackTag;
 


  
  
  
  always_comb begin
    wbIf.dataOut    = writeBackDataBuffer;
    wbIf.w_address  = writeBackAddressBuffer;
  end

  
  // Writeback FSM
  localparam [2:0]  IDLE          = 3'd0,
                    INITIATE      = 3'd1,
                    WAIT_FOR_ACK  = 3'd2,
                    CLEANUP       = 3'd3;



  reg [2:0] writebackState; 
  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      writebackState          <= IDLE;
      waitingForAck           <= 0;
      writeBackDataBuffer     <= '0;
      writeBackAddressBuffer  <= '0;
      wbIf.r_en               <= '0;
    end
    else begin

      case (writebackState)
        IDLE : begin
          if(wbIf.request) begin
            writebackState <= INITIATE;
          end
        end
        INITIATE : begin
          if(!waitingForAck) begin
            writebackState <= WAIT_FOR_ACK;
            waitingForAck <= 1'b1;
            writeBackAddressBuffer <= {nextWriteBackTag, '0};
            writeBackDataBuffer <= wbIf.dataIn;
            wbIf.r_en <= 1;
          end

        end
        WAIT_FOR_ACK : begin
          if(wbIf.ack) begin
            writebackState <= CLEANUP;
            wbIf.r_en <= 0;
            waitingForAck <= 0;
          end
        end

        CLEANUP : begin
          writebackState          <= IDLE;
          writeBackDataBuffer     <= '0;
          writeBackAddressBuffer  <= '0;
          writeBackTag            <= '0;
        end

        default : writebackState <= IDLE;
      endcase
    end
  end


  // ------------------------------------------
  // Retrieve Writeback Tag 
  // ------------------------------------------

  generate
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      // buffer of tag retrieved frow ways
      nextWriteBackTagBuffer[i] = (evicPolicyIf.evicitionTarget[i] === 1'b1) ? wayIfs[i].tag : 0;
    end
  endgenerate

  always_comb begin
    nextWriteBackTag = 0; 
    for(int i = 0; i <  NUM_WAYS; i++) begin
      nextWriteBackTag |= nextWriteBackTagBuffer[i];
    end
  end
endmodule