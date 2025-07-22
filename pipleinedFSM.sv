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
    WriteBackInterface        wbIf,
    MemoryFetcherInterface    memory_fetcher_if
  );


  
  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     = $clog2(WORDS_PER_BLOCK);
  localparam int TAG_WIDTH        = ADDRESS_WIDTH - OFFSET_WIDTH;

  localparam int REQUEST_WIDTH = OP + REQ_ID + ADDRESS_WIDTH;
  logic [REQUEST_WIDTH-1:0] request_pipe[NUM_PIPES]; 
  logic [ADDRESS_WIDTH-1:0]                               lookup_address;

  logic                 hit, miss, is_dirty, victim_is_dirty; // control flags
  logic[NUM_WAYS - 1:0] hit_way, eviction_target; // one-hot encoded targets
  // -------------------------------------------------------
  // Cache Pipeline
  // -------------------------------------------------------
  pipe0_t pipe0_q; // register to store pipe0 struct data
  logic   pipe0_valid, p0_processing, pipe0_ready;

  pipe1_t pipe1_q;
  logic   pipe1_valid, pipe1_ready;

  pipe2_t pipe2_q;
  logic   pipe2_valid, pipe2_ready;

  pipe3_t pipe3_q;
  logic   pipe3_ready;


  // Stage 0: Latch Request
  // Lookup is cominational and will identify HIT/MISS as soon as tag is latched
  always_ff @(posedge clk or negedge reset_n) begin : latch_request_ff
    if(!reset_n) begin
      pipe0_valid   <= 0;
      pipe0_q       <= '0;
      p0_processing <= 1'b0;
    end else if(controllerIf.valid & pipe0_ready) begin
      // Processing gives clock cycle for combinational lookup module to propogate
      // HIT / MISS results are latched on entry to stage 1 
      if(!p0_processing) begin
        // store raw request
        pipe0_q.raw_req <= controllerIf.request;

        // derive meta data from request
        pipe0_q.tag           <= controllerIf.request.mem_address >> OFFSET_WIDTH;
        pipe0_q.offset        <= controllerIf.request.mem_address[OFFSET_WIDTH-1:0];
        pipe0_q.block_address <= (controllerIf.request.mem_address) & {{TAG_WIDTH{1'b1}}, {OFFSET_WIDTH{1'b0}}};

        p0_processing <= 1'b1;

      end else begin
        // control propogation
        pipe0_valid <= 1'b1;
      end
    end else if (pipe0_valid & !pipe0_ready) begin
      // STALL
    end else begin
      pipe0_valid   <= 1'b0;
      pipe0_q       <= '0;
      p0_processing <= 1'b0;
    end
  end

  assign pipe0_ready = !pipe0_valid || pipe1_ready;

  // ------------------------------------------
  // Tag Lookup
  // ------------------------------------------
  assign wayLookupIf.tag = pipe0_q.tag;

  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      pipe1_q <= '0;
      p1_state <= IDLE;
    end
    else begin
      case (p1_state)
        IDLE : begin
          // Load Pipe
          if(pipe0_valid) begin
            pipe1_q <= '{
            prev_stage_data: pipe0_q,
            hit: wayLookupIf.hit,
            hit_way: wayLookupIf.hit_way,
            miss: wayLookupIf.miss,
            victim: evicPolicyIf.victim,
            victim_is_dirty: victim_is_dirty
            };
            p1_state <= PROCESS_EVICTION;
          end
        end
        PROCESS_EVICTION : begin
          if(evicPolicyIf.all_ways_updated) begin
            if(pipe2_ready) begin
              pipe1_q <= '0;
              p1_state <= IDLE;
            end 
            else begin
              p1_state <= STALL;
            end
          end
          // Else with for ways to update age
        end
        STALL : begin
          if(pipe2_ready) begin
            pipe1_q <= '0;
            p1_state <= IDLE;
          end
        end
      endcase
    end
  end

  assign pipe1_ready = p1_state == IDLE;



  // ------------------------------------------
  // Update polciy
  // ------------------------------------------
  // If hit hit is accessed, if miss victim is accessed promoting to mru
  // If pipe1 is not vallid assert '0 to targeting no ways in one-hot encoding
  // Way module takes 1 cycle to update age
  assign evicPolicyIf.accessed_way = (!pipe1_valid) ? '0 : (pipe1_q.hit) ? pipe1_q.hit_way : pipe1_q.victim;

  assign evicPolicyIf.updateAge = (p1_state == PROCESS_EVICTION);

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

  // Miss control signals 
  logic fetch_request, allocate_request, writeback_request; 
  logic fetch_done, allocate_done, writeback_done;
  

  // Execute control signals
  logic       write_request, read_request;
  logic       write_done, read_done;
  logic [2:0] write_id;
  

  typedef enum  logic [1:0] { 
    IDLE,
    HANDLE_MISS,
    EXECUTE
  } pipe3_state_t;

  pipe3_state_t p3_state;

  // Miss control 
  assign fetch_request      = (p3_state == HANDLE_MISS) && !fetch_done;
  assign writeback_request  = (p3_state == HANDLE_MISS) 
                              && pipe3_q.prev_stage_data.do_writeback 
                              && !writeback_done;
  assign allocate_request   = (p3_state == HANDLE_MISS) && !allocate_done;

  // Execute control
  assign write_request  = (p3_state == EXECUTE) && pipe3_q.prev_stage_data.do_write && !write_done;
  assign read_request   = (p3_state == EXECUTE) && pipe3_q.prev_stage_data.do_read && !read_done; 

  assign pipe3_ready = p3_state == IDLE;

  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      p3_state                <= IDLE;
      pipe3_q                 <= '0;
      fetch_done              <= 1'b0;
      allocate_done           <= 1'b0;
      writeback_done          <= 1'b0;
      write_id                <= '0;
    end else begin
      case(p3_state)
        IDLE : begin
          p3_state <= (pipe2_q.prev_stage_data.miss) ? HANDLE_MISS : EXECUTE; // Change state based on 
          pipe3_q.prev_stage_data <= pipe2_q;                                 // Capture previous state data;

        end
        HANDLE_MISS : begin
          // runs fetch/allocate and writeback concurrently


          // Wait for fetch completion signal
          if(!fetch_done & memory_fetcher_if.line_fill_valid)
            fetch_done <= 1'b1;
          // Wait for allocation completion signal
          if(!allocate_done & memory_fetcher_if.line_allocated_ack)
            allocate_done <= 1'b1;
          // wait for writeback completion signal
          if(!writeback_done & wbIf.wb_done)
            writeback_done <= 1'b1;

          // if no outstanding requests, proceed to execute
          if(!(fetch_request || writeback_request || allocate_request))
            p3_state <= EXECUTE;
          
        end
        EXECUTE : begin
          // read or write based on op wait for ack from appropriate moduel

          // wait for write ack
          // data transmitted by write module
          if(!write_done && id_match)
            write_done <= 1'b1;

          // Read is ready upon entry
          if(!read_done & controllerIf.cpu_read_ack) 
            read_done <= 1'b1;

          // Check if all conditions done
          if(!(read_request || write_request)) begin
            p3_state                <= IDLE;
            pipe3_q                 <= '0;
            fetch_done              <= 1'b0;
            allocate_done           <= 1'b0;
            writeback_done          <= 1'b0;
            write_id                <= ~write_id;
          end

        end
      endcase
    end
  end

  logic [1:0] bit_difference;
  logic id_match;
  always_comb begin
    bit_difference = '0;
    for(int i = 0; i < 3; i++)begin
      bit_difference += (writeToCacheIf.id_in_progress[i] != write_id[i]);
    end
    id_match = (bit_difference <= 1);
  end


  always_comb begin : way_data_reader_adressing
    wayDataReaderIf.offset = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.offset;
    wayDataReaderIf.target = pipe3_q.prev_stage_data.prev_stage_data.hit_way;
  end

  always_comb begin : write_to_cache_sending
    writeToCacheIf.write_id       = write_id;
    writeToCacheIf.offset         = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.offset;
    writeToCacheIf.targetWay      = pipe3_q.prev_stage_data.prev_stage_data.hit_way;
    writeToCacheIf.w_data         = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.raw_req.data;
    writeToCacheIf.write_request  = write_request; 
  end

  always_comb begin : fetch_logic
    controllerIf.fetch_address = pipe3_q.prev_stage_data.prev_stage_data.prev_stage_data.block_address;
    controllerIf.fetch_request = fetch_request;
  end
  

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
