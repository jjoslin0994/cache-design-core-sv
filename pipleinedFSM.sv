// cache Controller Top Design Module
`include "design_params.sv"
import design_params::*;
module CacheController #(
  parameter int	COUNTER_WIDTH 	= 8,
  parameter int	NUM_WAYS 		= 4,
  parameter int DATA_WIDTH		= 32,
  parameter int BLOCK_SIZE 		= 32,
  parameter int ADDRESS_WIDTH 	= 32

  // request params
  parameter int OP              = 2;
  parameter int REQ_ID          = 3;
  parameter int NUM_PIPES       = 5;

)(
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

  localparam int REQUEST_WIDTH = OP + REQ_ID + ADDRESS_WIDTH;
  logic [REQUEST_WIDTH-1:0] request_pipe[NUM_PIPES]; // Declare as [TOTAL_BITS-1:0]
  logic [ADDRESS_WIDTH-1:0]                               lookup_address;

  logic                                                   hit, miss, is_dirty, victim_is_dirty; // control flags
  logic[NUM_WAYS - 1:0]                                   hit_way, eviction_target; // one-hot encoded targets
  // -------------------------------------------------------
  // Cache Pipeline
  // -------------------------------------------------------
  pipe0_t pipe0_q; // register to store pipe0 struct data
  logic       pipe0_valid, pipe0_ready;

  pipe1_t pipe1_q;
  logic       pipe1_valid, pipe1_ready;

  pipe2_t pipe2_q;
  logic       pipe2_valid, pipe2_ready;

  pipe3_t pipe3_q;
  logic       pipe3_valid, pipe3_ready;


  // Stage 0: Latch Request
  always_ff @(posedge clk or negedge reset_n) begin : latch_request_ff
    if(!reset_n) begin
      pipe0_valid <= 0;
      pipe0_q <= '0;
    end else if(controllerIf.valid & pipe0_ready) begin
      // store raw request
      pipe0_q.raw_req <= controllerIf.request;

      // derive meta data from request
      pipe0_q.tag     <= controllerIf.request.mem_address >> OFFSET_WIDTH;
      pipe0_q.offset  <= controllerIf.request.mem_address[OFFSET_WIDTH-1:0];

      // control propogation
      pipe0_valid <= 1'b1;
    end else if (pipe0_valid & !pipe0_ready) begin
      // STALL
    end else begin
      pipe0_valid <= 1'b0;
      pipe0_q <= '0;
    end
  end

  assign pipe0_ready = !pipe0_valid || pipe1_ready;

  always_ff @(posedge clk or negedge reset_n) begin : tag_lookup_ff
    if(!reset_n)begin
      pipe1_valid <= 0;
      pipe1_q <= '0;
    end else if(pipe0_valid & pipe1_ready) begin
      pipe1_q <= '{
        hit: wayLookupIf.hit,
        hit_way: wayLookupIf.hit_way,
        miss: wayLookupIf.miss,
        victim: wayLookupIf.victim,
        victim_is_dirty: victim_is_dirty
      };
    end else if(pipe1_valid & !pipe1_ready) begin
      // STALL
    end else begin
      pipe1_valid <= 1'b0;
      pipe1_q <= '0;
    end
  end 

  assign pipe1_ready = !pipe1_valid || pipe2_ready;

  // ------------------------------------------
  // Tag Lookup
  // ------------------------------------------
  assign wayLookupIf.tag = pipe0_q.tag;
  // ------------------------------------------
  // Dirty Bit 
  // ------------------------------------------
  logic [NUM_WAYS-1:0] dirtyBitBuffer;
  generate
    for (genvar i = 0; i < NUM_WAYS; i++) begin
      assign dirtyBitBuffer[i] = (evicPolicyIf.evictionTarget[i] & wayIfs[i].dirty);
    end
  endgenerate
  
  always_comb begin
    victim_is_dirty = |(dirtyBitBuffer);
  end

  

  localparam [1:0]  NO_OP = 2'b00;
                    READ  = 2'b01,
                    WRITE = 2'b10; 
  
  always_ff @(posedge clk or negedge reset_n) begin : process_request
    if(!reset_n) begin
      pipe2_valid <= 0;
      pipe2_q <= '0;
    end else if (pipe1_valid & pipe2_ready) begin
      pipe2_q.prev_stage_data <= pipe1_q;

      case (pipe1_q.prev_stage_data.raw_req.op)
        READ : begin
          pipe2_q.do_read   <= pipe1_q.hit;
          pipe2_q.do_write  <= 1'b0;
        end

        WRITE : begin
          pipe2_q.do_write  <= pipe1_q.hit;
          pipe2_q.do_read   <= 1'b0;
        end
        default: begin
          pipe2_q.do_read  <= 1'b0;
          pipe2_q.do_write <= 1'b0;
        end
      endcase

      pipe2_q.do_fetch      <= pipe1_q.miss;
      pipe2_q.do_allocate   <= pipe1_q.miss;
      pipe2_q.do_writeback  <= pipe1_q.miss & pipe1_q.victim_is_dirty;
      pipe2_valid <= 1;
    end else if (pipe2_valid & !pipe2_ready) begin
      // STALL
    end else begin
      pipe2_valid <= 1'b0;
      pipe2_q <= '0;
    end
  end

  assign pipe2_ready = !pipe2_valid || pipe3_ready;

  always_ff @(posedge clk or negedge reset_n) begin : fulfill_request
    if(!reset_n) begin
      pipe3_valid <= 1'b0;
      pipe3_q <= '0;
      pipe3_started <= 1'b0;
      pipe3_done <= 1'b0;
    end else if (pipe2_valid & pipe3_ready) begin
      pipe3_q.prev_stage_data <= pipe2_q;
      pipe3_valid <= 1'b1;
    end
    else if (pipe3_valid & !pipe3_started) begin
      // Begin execution based on command
      case (1'b1)
        pipe3_q.prev_stage_data.do_read: begin
          pipe3_started <= 1'b1;
          // do_read logic
        end
        pipe3_q.prev_stage_data.do_write: begin
          pipe3_started <= 1'b1;
          // do_write logic
        end
        pipe3_q.prev_stage_data.do_fetch: begin
          pipe3_started <= 1'b1;
          // do_fetch logic
        end
        pipe3_q.prev_stage_data.do_allocate: begin
          pipe3_started <= 1'b1;
          // do_allocate logic
        end
        pipe3_q.prev_stage_data.do_writeback: begin
          pipe3_started <= 1'b1;
          // do_writeback logic
        end
        default : begin
          // bad state flush
          pipe3_valid <= 1'b0;
          pipe3_q <= '0;
          pipe3_started <= 1'b0;
          pipe3_done <= 1'b0;
        end
      endcase

    end
    else if(pipe3_valid & !pipe3_done) begin
      // STALL
      pipe3_done <= pipe3_next_done;
    end
    else begin
      pipe3_valid <= 1'b0;
      pipe3_q <= '0;
      pipe3_started <= 1'b0;
      pipe3_done <= 1'b0;
    end
  end

  assign pipe3_ready = !pipe3_valid;
  assign pipe3_next_done = (pipe3_q.prev_stage_data.do_allocate & evictionIf.ack ) 
                          || (pipe3_q.prev_stage_data.do_read & controllerIf.cpu_ack)
                          || (pipe3_q.prev_stage_data.do_write & writeToCacheIf.cache_w_ack)
                          || (pipe3_q.prev_stage_data.do_writeback & wbIf.ack);


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


endmodule
