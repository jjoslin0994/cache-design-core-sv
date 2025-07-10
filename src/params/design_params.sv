package design_params;

  parameter int OP              = 2;
  parameter int REQ_ID          = 3;
  parameter int ADDRESS_WIDTH   = 32;
  parameter int NUM_WAYS        = 4;
  parameter int DATA_WIDTH      = 32;
  parameter int BLOCK_SIZE      = 32;

  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     = $clog2(WORDS_PER_BLOCK);
  localparam int TAG_WIDTH        = ADDRESS_WIDTH - OFFSET_WIDTH;

  typedef struct packed {
    logic [OP - 1:0]          op;
    logic [REQ_ID-1:0]        req_id; 
    logic [ADDRESS_WIDTH-1:0] mem_address;
    logic [DATA_WIDTH-1:0]    data;
  } cpu_raw_request_t;


  typedef struct packed {
    cpu_raw_request_t         raw_req;
    logic [OFFSET_WIDTH-1:0]  offset;
    logic [TAG_WIDTH-1:0]     tag;
  } pipe0_t;

  typedef struct packed {
    pipe0_t           prev_stage_data;
    logic                 hit;
    logic                 hit_way; 
    logic                 miss;
    logic [NUM_WAYS-1:0]  victim;
    logic                 victim_is_dirty;
  } pipe1_t;

  typedef struct packed {
    pipe1_t prev_stage_data;
    logic       do_fetch;
    logic       do_allocate;
    logic       do_read;
    logic       do_write;
    logic       do_writeback;
  } pipe2_t;

  typedef struct packed {
    pipe2_t prev_stage_data;
    logic ready_to_send;           
  } pipe3_t;

endpackage
