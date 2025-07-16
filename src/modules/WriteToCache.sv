/*
  Jonathan Joslin 7/12/25
  WriteToCache module writes data from CPU registers to a selected cache way in a set-associative cache.
  - NUM_WAYS: Number of cache ways (default 4).
  - DATA_WIDTH: Width of data bus (default 32 bits).
  - OFFSET_WIDTH: Width of offset field for addressing within a cache line.
  - Interfaces: Connects to WayInterface (cache ways) and WriteToCacheInterface (CPU write requests).
  - Assumes synchronous operation with active-low reset.
*/
module WriteToCache #(
  parameter int NUM_WAYS    = 4,
  parameter int DATA_WIDTH  = 32,
  parameter int OFFSET_WIDTH
)(
  input logic                 clk, reset_n,
  WayInterface.write          wayIfs[NUM_WAYS],
  WriteToCacheInterface.slave writeToCacheIf
);

  // data
  logic [NUM_WAYS - 1:0]      target_one_hot;
  logic [OFFSET_WIDTH - 1:0]  w_offset;
  logic [DATA_WIDTH - 1:0]    w_data; 

  // control
  logic write_setup_ready, write_offset_valid, w_ack, request_ack_q;
  logic [NUM_WAYS - 1:0] ack_buffer;

  assign write_setup_ready = !write_offset_valid || w_ack;  // Ready to recieve new data if current data invalid or prev data stored.

  assign writeToCacheIf.request_ack = request_ack_q;        // Update controll FSM that request was recieved

  assign writeToCacheIf.w_ack = w_ack;                      // pass up to control module
  
  // ----------------------------------------
  // Sending
  // ----------------------------------------
  // One-hot encoding to send data to correct way
  generate
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign wayIfs[i].offset = w_offset;
      assign wayIfs[i].w_en   = write_offset_valid & target_one_hot[i];
      assign wayIfs[i].dataIn = w_data;
    end
  endgenerate

  // ----------------------------------------
  // Receiving 
  // ----------------------------------------

  generate
    // Assumes one-hot encoding of ways, only way written to will have asserted w_ack
    for(genvar i = 0; i < NUM_WAYS; i++) begin
      assign ack_buffer[i] = wayIfs[i].w_ack;
    end
  endgenerate

  always_comb begin
    w_ack = |ack_buffer;
  end

  

  // ----------------------------------------
  // Flow Control 
  // ----------------------------------------
  always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin // Reset State
      write_offset_valid  <= 1'b0;
      target_one_hot      <= '0;
      w_offset            <= '0;
      w_data              <= '0;
      request_ack_q       <= 1'b0;
    end 
    else if(write_setup_ready & writeToCacheIf.request)begin
      // write upon request if ready
      w_offset            <= writeToCacheIf.offset;
      w_data              <= writeToCacheIf.w_data;
      target_one_hot      <= writeToCacheIf.targetWay;
      write_offset_valid  <= 1'b1;                    
      request_ack_q       <= 1'b1;                    // Request recieved
    end 
    else if(write_offset_valid & !write_setup_ready) begin
      // STALL for ack
      request_ack_q <= 1'b0; // De-assert to allow main cotrol to flow.
    end
    else begin
      write_offset_valid  <= 1'b0;
      target_one_hot      <= '0;
      w_offset            <= '0;
      w_data              <= '0;
    end 
  end






endmodule