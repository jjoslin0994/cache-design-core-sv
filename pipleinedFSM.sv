// cache Controller Top Design Module
`include "design_params.sv"
import design_params::*;
module CacheController #(
  parameter int	COUNTER_WIDTH 	= 8,
  parameter int	NUM_WAYS 		    = 4,
  parameter int DATA_WIDTH		  = 32,
  parameter int BLOCK_SIZE 		  = 32,
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
  logic       pipe3_executing, pipe3_ready;


  // Stage 0: Latch Request
  always_ff @(posedge clk or negedge reset_n) begin : latch_request_ff
    if(!reset_n) begin
      pipe0_valid <= 0;
      pipe0_q <= '0;
    end else if(controllerIf.valid & pipe0_ready) begin
      // store raw request
      pipe0_q.raw_req <= controllerIf.request;

      // derive meta data from request
      pipe0_q.tag           <= controllerIf.request.mem_address >> OFFSET_WIDTH;
      pipe0_q.offset        <= controllerIf.request.mem_address[OFFSET_WIDTH-1:0];
      pipe0_q.block_address <= (controllerIf.request.mem_address) & {{TAG_WIDTH{1'b1}}, {OFFSET_WIDTH{1'b0}}};

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
          pipe2_q.do_read   <= 1'b1;
          pipe2_q.do_write  <= 1'b0;
        end

        WRITE : begin
          pipe2_q.do_write  <= 1'b1;
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

  logic read_output_valid;
  logic write_request_q; // flag used to start cache write module
  logic fetch_request; // flag used to start memeroy fetch process
  logic fetch_done, allocate_done, writeback_done;
  logic miss_done;

  typedef enum  logic [2:0] { 
    IDLE,
    HANDLE_MISS,
    EXECUTE,
    WAIT_FOR_ACK
  } pipe3_state_t;

  pipe3_state_t p3_state;

  assign fetch_request      = (p3_state == HANDLE_MISS) && !fetch_done;
  assign writeback_request  = (p3_state == HANDLE_MISS) 
                              && pipe3_q.prev_stage_data.do_writeback 
                              && !writeback_done;
  assign allocate_request   = (p3_state == HANDLE_MISS) && !allocate_done;


  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      p3_state                <= IDLE;
      pipe3_q                 <= '0
      fetch_done              <= 1'b0;
      allocate_done           <= 1'b0;
      writeback_done          <= 1'b0;
    end else begin
      case(p3_state)
        IDLE : begin
          p3_state <= (pipe2_q.prev_stage_data.miss) ? HANDLE_MISS : EXECUTE; // Change state based on 
          pipe3_executing <= 1'b1;                                            // mark as running
          pipe3_q.prev_stage_data <= pipe2_q;                                 // Capture previous state data;

        end
        HANDLE_MISS : begin
          // Wait for fetch completion signal
          if(!fetch_done & memory_fetcher_if.line_fill_valid)
            fetch_done <= 1'b1;
          // Wait for allocation completion signal
          if(!allocate_done & memory_fetcher_if.line_allocated_ack)
            allocate_done <= 1'b1;
          // wait for writeback completion signal
          if(!writeback_done & wbIf.wb_done)
            writeback_done <= 1'b1;

          // if no outstanding requests, proceed
          if(!(fetch_request || writeback_request || allocate_request))
            p3_state <= EXECUTE;
          
        end
        EXECUTE : begin
          case (1'b1)
            pipe3_q.prev_stage_data.do_read: begin
              // assignment of offset happended on leaving idle
              // read value should be conform to target
              p3_state <= WAIT_FOR_ACK;
            end
            pipe3_q.prev_stage_data.do_write: begin
              pipe3_started   <= 1'b1;
              write_request_q <= 1'b1; // start FSM in WriteToCache module
            end
            
            default : begin
              // bad state flush
              pipe3_q     <= '0;
              pipe3_done  <= 1'b0;
              p3_state    <= IDLE;
            end
          endcase
        end
        WAIT_FOR_ACK : begin
          if(pipe3_done) begin
            p3_state                <= IDLE;
            pipe3_q                 <= '0
            fetch_done              <= 1'b0;
            allocate_done           <= 1'b0;
            writeback_done          <= 1'b0;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin : fulfill_request

    if(!reset_n) begin
      pipe3_executing     <= 1'b0;
      pipe3_q         <= '0;
      pipe3_started   <= 1'b0;
      pipe3_done      <= 1'b0;
      write_request_q <= 1'b0;
      fetch_done      <= 1'b0;
      allocate_done   <= 1'b0;
      writeback_done  <= 1'b0;
      miss_done       <= 1'b0;
    end else if (pipe2_valid & pipe3_ready) begin // start FSM
      pipe3_q.prev_stage_data <= pipe2_q;
      pipe3_executing <= 1'b1;
    end

    else if (pipe3_executing & !pipe3_started) begin
      
      // Check for miss condition or process hit
      if(pipe3_q.prev_stage_data.prev_stage_data.miss ^ miss_done) begin // Handle Miss
        if(writeback_done & fetch_done & allocate_done) begin
          miss_done <= 1'b1;
        end
        // run fetch and write back concurrently
        else if(pipe3_q.prev_stage_data.do_fetch) begin
          if(!fetch_request_q)
            fetch_request_q <= 1; // signal start of fetch request
          else begin
            if(memory_fetcher_if.line_fill_valid & !fetch_done) begin
              fetch_request <= 1'b0;
              fetch_done    <= 1'b1;
            end else if(fetch_request_q) begin
              // STALL: waiting for data from memory
            end else begin
              if(memory_fetcher_if.line_allocated_ack) begin
                allocate_done <= 1'b1;
              end
            end
          end
        end

        if(pipe3_q.prev_stage_data.do_writeback) begin

        end
      end else begin // Hit or miss handled
        case (1'b1)
          pipe3_q.prev_stage_data.do_read: begin
            // combinational module data ready upon entry (see way_data_reader_adressing)
            pipe3_started <= 1'b1;
          end
          pipe3_q.prev_stage_data.do_write: begin
            pipe3_started   <= 1'b1;
            write_request_q <= 1'b1; // start FSM in WriteToCache module
          end
          
          default : begin
            // bad state flush
            pipe3_executing <= 1'b0;
            pipe3_q <= '0;
            pipe3_started <= 1'b0;
            pipe3_done <= 1'b0;
          end
        endcase
      end
    end
    else if(pipe3_executing & !pipe3_done) begin
      // STALL
      pipe3_done <= pipe3_done;
    end
    else begin
      pipe3_executing     <= 1'b0;
      pipe3_q         <= '0;
      pipe3_started   <= 1'b0;
      pipe3_done      <= 1'b0;
      write_request_q <= 1'b0;
    end
  end

  always_comb begin : way_data_reader_adressing
    wayDataReaderIf.offset = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.offset;
    wayDataReaderIf.target = pipe3_q.prev_stage_data.prev_stage_data.hit_way;
  end

  always_comb begin : write_to_cache_sending
    writeToCacheIf.offset         = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.offset;
    writeToCacheIf.targetWay      = pipe3_q.prev_stage_data.prev_stage_data.hit_way;
    writeToCacheIf.w_data         = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.raw_req.data;
    writeToCacheIf.write_request  = write_request_q; 
  end

  always_comb begin : write_to_cache_receiving

  end


  always_comb begin : fetch_logic
    controllerIf.fetch_address = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.block_address;
    contorllerIf.fetch_request = fetch_request_q;
  end

  assign pipe3_ready = !pipe3_executing;
  assign pipe3_done = (pipe3_q.prev_stage_data.do_read & controllerIf.cpu_ack)
                          || (pipe3_q.prev_stage_data.do_write & writeToCacheIf.request_ack);
  


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
