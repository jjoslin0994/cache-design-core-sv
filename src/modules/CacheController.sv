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
    CacheDataFetcherInterface CacheDataFetcherIf
  );
  
  
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

  // -------------------------------------------------------
  // Flow Cotrol FSM
  // -------------------------------------------------------

  localparam IDLE         = 3'd0; // Wait for CPU request
  localparam LOOKUP       = 3'd1; // Compare tags of ways
  localparam HIT          = 3'd2; // If hit get data from way
  localparam MISS         = 3'd3; // Send requested data to registers
  localparam ALLOCATE     = 3'd4; // Wrtie back from registers
  localparam READ         = 3'd5; // Handle Miss (Get eviction target from Policy Module) request data from Main Mem
  localparam WRITE        = 3'd6; // Overwrite way marked for eviction 
  // localparam ALLOCATE_W   = 3'd7; // Allcoate register for write from registers

  logic [2:0]             controlState;
  logic [NUM_WAYS - 1:0]  dirtyBitBuffer;
  logic                   victimIsDirty; 

  logic [DATA_WIDTH - 1:0] dataToCpu;

  always_ff @(posedge clk or negedge reset_n) begin : CacheFlowControl
    if(!reset_n) begin
      controlState <= IDLE;
    end
    else begin
      case (controlState)
        IDLE : begin
          if(controllerIf.request)begin
            controlState <= LOOKUP;
          end
        end

        LOOKUP : begin 
          if(wayLookupIf.hit === 1'b1) begin
            controlState <= HIT;
          end 
          else if(wayLookupIf.miss === 1'b1)
            controlState <= MISS;
        end

        HIT : begin
          // Policy updat
          evicPolicyIf.hit        <= (wayLookupIf.hit == 1'b1); 
          evicPolicyIf.hitWay     <= wayLookupIf.hitWay;
          evicPolicyIf.miss       <= '0; 

          if(controllerIf.read) begin // fetch data from way 
            CacheDataFetcherIf.targetWay <= wayLookupIf.hitWay;
            controlState <= READ;
          end
          if(controllerIf.write) begin
            controlState <= WRITE;
          end

        end

        MISS : begin // check dirty bit, wiriteback as needed, wait for validation from writeback moduel
          evicPolicyIf.miss <= (wayLookupIf.hit == 1'b0);
          controlState <= ALLOCATE;
          if(victimIsDirty)
            controlState <= WRITEBACK;
          else
            controlState <= ALLOCATE;
        end

        WRITEBACK : begin

          controlState <= ALLOCATE;
        end

        ALLOCATE : begin


          if(controllerIf.read) begin // fetch data from way 
            CacheDataFetcherIf.targetWay <= wayLookupIf.hitWay;
            controlState <= READ;
          end
          if(controllerIf.write) begin
            controlState <= WRITE;
          end
        end

        READ : begin
          controllerIf.dataToRegister <= CacheDataFetcherIf.dataOut; // send read data to CPU register
        end

        WRITE : begin // Write to Cache

        end

        default: controlState <= IDLE;
      endcase

    end

  end
  
  generate

    for (genvar i = 0; i < NUM_WAYS; i++) begin
      assign dirtyBitBuffer[i] = (evicPolicyIf.evictionTarget[i] & wayIfs[i].dirty);
    end

  endgenerate
  
  always_comb begin
    victimIsDirty = |(dirtyBitBuffer);
  end
  
  
endmodule
