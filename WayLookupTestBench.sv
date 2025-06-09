`include "design_params.sv"
import design_params::*;

class WayLookupTest;

  randc bit [TAG_WIDTH - 1:0] expectedHits[NUM_WAYS]; // to be loaded upon random

  randc bit [TAG_WIDTH - 1:0] expectedMiss[NUM_WAYS]; // loaded with random address not found in the expected hits array


  constraint MutualExclusion {
    foreach (expectedHits[i]) {
      foreach (expectedMiss[j]) {
        expectedHits[i] != expectedMiss[j];
      }
    }
  }

  function void PopulateArrays();
    assert (this.randomize()) 
    else   $fatal("Radomization failed");

    $display("Expected HITs: ");
    foreach (expectedHits[i])
      $display("  Hit[%0d] = %h", i, expectedHits[i]);

    foreach (expectedMiss[i])
      $display("  Miss[%0d] = %h", i, expectedMiss[i]);
      

  endfunction
endclass

module tb_top;
  logic clk, reset_n;

  // ----------------------------------
  // Instantiate WayLookupInterface
  // ----------------------------------
  WayLookupInterface #(
    .NUM_WAYS(NUM_WAYS),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
  ) wayLookupIfInst();


  WayLookupInterface.master WayLookupIfMasterInst;

  WayLookupInterface.slave WayLookupIfSlaveInst;

  // -----------------------------------------------
  // Instantiate array of WayInterface(s)
  // -----------------------------------------------
  WayInterface #(
    .COUTNER_WIDTH(8),
    .NUM_WAYS(4),
    .DATA_WIDTH(32),
    .BLOCK_SIZE(32),
    .ADDRESS_WIDTH(32)
  ) wayIfs[NUM_WAYS](); 

  WayInterface.master wayIfs_master[NUM_WAYS];


  logic [TAG_WIDTH - 1:0] wayTags[NUM_WAYS];


  WayLookup #(
    .NUM_WAYS(NUM_WAYS),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
  ) lookupInst (
    .clk(clk),
    .reset_n(reset_n),
    .LookupIf(wayLookupIfInst),
    .wayIfs(wayIfs)
  );
  
  always #5 clk = ~clk; // clock signal


  //clock generation
  initial begin 
    WayLookupTest test = new();
    test.PopulateArrays();

    reset_n = 0;
    #20;
    reset_n = 1;

    foreach (wayIfs_master[i])
      wayIfs_master[i] = wayIfs[i];

    WayLookupIfMasterInst = wayLookupIfInst;
    WayLookupIfSlaveInst  = wayLookupIfInst;

    foreach(wayTags) // load ways with expected tag values
      wayTags[i] = test.expectedHits[i];


    clk = 0;
  
    // -----------------------------------------------
    // Lookup Module DUT
    // -----------------------------------------------


    int i = 0;
    

    repeat(NUM_WAYS) begin // expected hits block
      WayLookupIfMasterInst.tag = wayTags[i];
      wayIfs[i].valid = 1'b1;
      #1;
      assert(WayLookupIfSlaveInst.hit && !WayLookupIfSlaveInst.miss) else
        $display("Error: should be hit because found and valid");

      wayIfs[i].valid = 0'b1;
      assert(!WayLookupIfSlaveInst.hit && WayLookupIfSlaveInst.miss) else
        $display("Found but invalid");
      i++; 
    end

    repeat(NUM_WAYS) begin // expected miss block

    end


  end
  
endmodule