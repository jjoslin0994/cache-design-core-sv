module WriteWord #(
  parameter int DATA_WIDTH    = 32,
  parameter int BLOCK_SIZE    = 32,
  parameter int ADDRESS_WIDTH = 32
)
(
  logic clk, reset_n,

  WriteWordInterface.slave  wwIf,
  WayInterface.write        wayIfs[NUM_WAYS],
);

  localparam int WORDS_PER_BLOCK  = (BLOCK_SIZE / (DATA_WIDTH / 8));
  localparam int OFFSET_WIDTH     =	$clog2(WORDS_PER_BLOCK);

  logic [(BLOCK_SIZE - 1) * 8:0]  write_mask;
  logic [DATA_WIDTH - 1:0]        write_data_latch;
  logic [ADDRESS_WIDTH - 1:0]     address_latch;
  logic [OFFSET_WIDTH - 1:0]      offset;

  logic [2:0] write_state;

  always_ff @(posedge clk, negedge reset_n) begin
    if(!reset_n) begin
      write_mask        <= '0;
      write_data_latch  <= '0;
      address_latch     <= '0;
    end else begin
      case (write_state)
        IDLE : begin
          if(wwIf.w_en) begin
            write_data_latch  <= wwIf.word_data;
            address_latch     <= wwIf.word_address;
          end
        end
      endcase
    end
  end

  always_comb begin

  end

  logic cacheline_buffer [WORDS_PER_BLOCK * DATA_WIDTH - 1:0];

  generate

    
  endgenerate


endmodule