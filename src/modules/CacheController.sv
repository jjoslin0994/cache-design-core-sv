// cache Controller Top Design Module

module CacheController #(
  parameter int	COUNTER_WIDTH 	= 8,
  parameter int	NUM_WAYS 		= 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH 	= 32
)
  (
    input logic 			      clk, reset_n, // global signals 

    // Full Interfaces passed in from testbench
    ControllerInterface 	    controllerIf,
    WayInterface 			        wayIfs[NUM_WAYS],
    WayLookupInterface		    wayLookupIf,
    EvictionPolicyInterface   evicPolicyIf,
    EvictionInterface         evictionIf,
    WayDataReaderInterface    wayDataReaderIf,
    WriteToCacheInterface     writeToCacheIf,
    WriteBackInterface        wbIf
  );

  
  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     = $clog2(WORDS_PER_BLOCK);
  localparam int TAG_WIDTH        = ADDRESS_WIDTH - OFFSET_WIDTH;
  
  //----------------------------------------------
  // Instantiate Eviction Policy
  //----------------------------------------------
  LruEvictionPolicy #(
    .NUM_WAYS(NUM_WAYS)
  ) LruPolicyInst(
    .clk(clk),
    .reset_n(reset_n),
    .wayIfs(wayIfs),
    .wayLookupIf(wayLookupIf),
    .evicPolicyIf(evicPolicyIf)
  );
  
  
  //----------------------------------------------
  // Instantiate Ways
  //----------------------------------------------
  
  generate
    for (genvar i = 0; i < NUM_WAYS; i++) begin : GenerateWays
      Way #(
        .NUM_WAYS(NUM_WAYS),
        .ID(i),
        .COUNTER_WIDTH($clog2(NUM_WAYS)),
        .DATA_WIDTH(DATA_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
        ) WayInst (
        .clk(clk),
        .reset_n(reset_n),
        .wayIfs(wayIfs[i].internal)
      );  
    end : GenerateWays
  endgenerate
  
  //----------------------------------------------
  // Instantiate Lookup Module
  //----------------------------------------------
  WayLookup #(
    .NUM_WAYS(NUM_WAYS),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
  ) lookupInst (
    .clk(clk),
    .reset_n(reset_n),
    .LookupIf(wayLookupIf),
    .wayIfs(wayIfs)
  );

  // ---------------------------------------------
  // Instantiate WayDataReader Module
  // ---------------------------------------------
  WayDataReader #(
    .NUM_WAYS(NUM_WAYS),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH)
  ) wayDataReaderInst(
    .wayIfs(wayIfs),
    .WayDataReaderIf(wayDataReaderIf)
  );

  // ---------------------------------------------
  // Instantiate Writeback Module
  // ---------------------------------------------
  WriteBack #(
    .NUM_WAYS(NUM_WAYS),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH)

  ) writeBackInst(
    .clk(clk),
    .reset_n(reset_n),
    .evicPolicyIf(evicPolicyIf),
    .wayIfs(wayIfs),
    .wbIf(wbIf)
  );

  // -----------------------------------------------------
  // Instantiate Write To Cache module 
  // -----------------------------------------------------
  WriteToCache #(
    .NUM_WAYS(NUM_WAYS),
    .DATA_WIDTH(DATA_WIDTH)
  )writeToCacheInst(
    .wayIfs(wayIfs),
    .writeToCacheIf(writeToCacheIf)
  );

  // -----------------------------------------------------
  // Instantiate Eviction/Allocate module 
  // -----------------------------------------------------
  EvictAndAllocateWay #(
    .NUM_WAYS(NUM_WAYS),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
  )evictAllocateInst(
    .clk(clk),
    .reset_n(reset_n),
    .evictionIf(evictionIf),
    .wayIfs(wayIfs)
  );

  // -------------------------------------------------------
  // Flow Cotrol FSM
  // -------------------------------------------------------

  localparam [2:0]  IDLE         = 3'd0, // Wait for CPU request
                    LOOKUP       = 3'd1, // Compare tags of ways
                    HIT          = 3'd2, // If hit get data from way
                    MISS         = 3'd3, // Send requested data to registers
                    ALLOCATE     = 3'd4, // Wrtie back from registers
                    READ         = 3'd5, // Handle Miss (Get eviction target from Policy Module) request data from Main Mem
                    WRITE        = 3'd6; // Overwrite way marked for eviction 

  logic [2:0]                 controlState;
  logic [NUM_WAYS - 1:0]      dirtyBitBuffer;
  logic                       victimIsDirty; 

  logic [DATA_WIDTH - 1:0]    cpuRequestAddress_latched;  // local copy of last request
  logic [DATA_WIDTH - 1:0]    read_data_latch;
  logic                       readyToSend;
  logic [OFFSET_WIDTH - 1:0]  offset, offset_latch;
  logic                       read,                       // CPU read request
                              write,                      // CPU write request
                              validAddress,               // latched address is valid
                              updateAge;                  // gate LRU age update 

  always_ff @(posedge clk or negedge reset_n) begin : CacheFlowControl
    if(!reset_n) begin
      controlState <= IDLE;
      cpuRequestAddress_latched  <= '0;
      read                       <= 0;
      write                      <= 0;
      validAddress               <= 0;
      updateAge                  <= 0;
      readyToSend                <= 0;
    end
    else begin
      case (controlState)
        IDLE : begin
          if(controllerIf.request)begin
            controlState              <= LOOKUP;
            read                      <= controllerIf.read;
            write                     <= controllerIf.write;
            readyToSend               <= 0;
            validAddress              <= 1;
            cpuRequestAddress_latched <= controllerIf.cpuRequestAddress;
          end
        end

        LOOKUP : begin 
          if(wayLookupIf.hit === 1'b1) begin
            controlState <= HIT;
          end 
          else if(wayLookupIf.miss === 1'b1)
            controlState <= MISS;

          updateAge     <= 1;
          offset_latch  <= offset;
        end

        HIT : begin

          if(controllerIf.read) begin // fetch data from way 
            read_data_latch <= wayDataReaderIf.dataOut;
            controlState <= READ;
          end
          if(controllerIf.write) begin
            controlState <= WRITE;
          end
          updateAge      <= 0;
        end

        MISS : begin // check dirty bit, wiriteback as needed, wait for validation from writeback moduel

          if(victimIsDirty) begin
            wbIf.request <= 1; // Send request to WriteBack modlue
            controlState <= WRITEBACK;
          end else
            controlState <= ALLOCATE;

            updateAge    <= 0;
        end

        WRITEBACK : begin // To Main Memory
          if(!wbIf.waitingForAck)begin
            wbIf.dataIn <= wayDataReaderIf.dataOut;
            wbIf.request <= 0; 
            controlState <= ALLOCATE;
          end

        end

        ALLOCATE : begin

          if(controllerIf.read) begin // fetch data from way 
            controlState <= READ;
          end
          if(controllerIf.write) begin
            controlState <= WRITE;
          end
        end

        READ : begin
          readyToSend <= 1;
        end

        WRITE : begin // Write to Cache

        end

        default: controlState <= IDLE;
      endcase

    end

  end

  generate
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].updateAge = updateAge;
    end

  endgenerate
  
  

  // ------------------------------------------
  // Dirty Bit 
  // ------------------------------------------
  generate

    for (genvar i = 0; i < NUM_WAYS; i++) begin
      assign dirtyBitBuffer[i] = (evicPolicyIf.evictionTarget[i] & wayIfs[i].dirty);
    end

  endgenerate
  
  always_comb begin
    victimIsDirty = |(dirtyBitBuffer);
  end

  // ------------------------------------------
  // Mask Tag
  // ------------------------------------------
  always_comb begin
    wayLookupIf.tag = (cpuRequestAddress_latched >> OFFSET_WIDTH);
  end

  // --------------------------------------------
  // Eviction Policy Assignments
  // --------------------------------------------
  always_comb begin
    evicPolicyIf.hit    = (wayLookupIf.hit == 1'b1);
    evicPolicyIf.hitWay = wayLookupIf.hitWay;
    evicPolicyIf.miss   = wayLookupIf.miss;
  end

  // --------------------------------------------
  // Read way based on current control state
  // --------------------------------------------
  always_comb begin
    wayDataReaderIf.target = (controlState == HIT || controlState == ALLOCATE) ? wayLookupIf.hitWay 
    : (controlState == WRITEBACK) ? evicPolicyIf.evictionTarget 
    : '0;
  end

  // -------------------------------------------------
  // Compute Offset
  // -------------------------------------------------
  always_comb begin
    offset = controllerIf.cpuRequestAddress_latched[OFFSET_WIDTH - 1:0];
  end

  // -------------------------------------------------
  // Propogate offset to Data Reader
  // -------------------------------------------------
  always_comb begin
    wayDataReaderIf.offset = offset_latch;
  end


endmodule
