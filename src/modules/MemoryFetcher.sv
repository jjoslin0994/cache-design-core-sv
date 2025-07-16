module MemoryFetcher #(
  parameter int DATA_WIDTH  = 32,
  parameter int BLOCK_SIZE  = 32
)(
  input logic clk, reset_n,

  MemoryFetcherInterface.internal memory_fetcher_if
);

localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
localparam int WORD_COUNTER_WIDTH = $clog2(WORDS_PER_BLOCK);

typedef enum logic [1:0] { 
  IDLE,
  FETCH,
  WAIT_FOR_ACK,
} fetch_state_t;

fetch_state_t f_state;

logic [DATA_WIDTH-1:0] line_fill_buffer [WORDS_PER_BLOCK];
logic [WORD_COUNTER_WIDTH-1:0] word_index;

assign memory_fetcher_if.line_fill_ready  = f_state == IDLE;          // Module is ready for new data
assign memory_fetcher_if.line_fill_valid  = f_state == WAIT_FOR_ACK;  // data is ready to be stored

assign memory_fetcher_if.line_fill_o = line_fill_buffer;  // Send data to way

always_ff @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin 
    f_state     <= IDLE;
    word_index  <= '0;

    for(int i = 0; i < WORDS_PER_BLOCK; i++) begin
      line_fill_buffer[i] <= '0;
    end
  end
  else begin
    unique case (f_state)
      IDLE : begin
        if(memory_fetcher_if.fetch_request) begin
          word_index  <= 0;
          f_state     <= FETCH;
        end
      end
      FETCH : begin
        if (memory_fetcher_if.fetched_word_valid) begin
          line_fill_buffer[word_index] <= memory_fetcher_if.mem_data;

          word_index <= word_index + 1;

          if(word_index + 1 == WORDS_PER_BLOCK)
            f_state <= WAIT_FOR_ACK;
        end
      end
      WAIT_FOR_ACK : begin
        if(memory_fetcher_if.line_allocated_ack) begin
          word_index  <= '0;
          f_state     <= IDLE;
          for(int i = 0; i < WORDS_PER_BLOCK; i++) begin
            line_fill_buffer[i] <= '0;
          end
        end
      end
    endcase
  end
end

endmodule