package design_params;

  parameter int ADDRESS_WIDTH = 32;
  parameter int BLOCK_SIZE    = 32;
  parameter int NUM_WAYS      = 4;
  parameter int DATA_WIDTH 	  = 32;

  localparam int OFFSET_WIDTH = $clog2(BLOCK_SIZE);
  localparam int TAG_WIDTH    = ADDRESS_WIDTH - OFFSET_WIDTH;

endpackage
