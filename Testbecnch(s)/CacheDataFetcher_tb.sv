`include "design_params.sv"
import design_params::*;

class CacheFetchTest;
  rand bit [DATA_WIDTH - 1:0] testData[NUM_WAYS]; // Dummy way data
  
  
  function void populateArray();
    assert (this.randomize())
      else $fatal("Randomization failed");
    
    $display("Loaded Data");
    foreach (testData[i])
      $display("	Data[%0d] = %h", i , testData[i]);
  endfunction
endclass

module tb_CacheFetcher;
  logic clk, reset_n;
  int i = 0;
  int j = 0;
  int k = 0;
  
  
    
  // -------------------------------------------------------
  // Instantiate CacheDataFetcher Interface
  // -------------------------------------------------------
  CacheDataFetcherInterface #(
    .NUM_WAYS(NUM_WAYS),
    .DATA_WIDTH(DATA_WIDTH)
  )cacheDataFetcherIf();
  
  virtual CacheDataFetcherInterface.master fetcherIfMaster;
  virtual CacheDataFetcherInterface.slave fetcherIfSlave;


  
  
  // -------------------------------------------------------
  // Instantiate array of Way Interfaces
  // -------------------------------------------------------
    WayInterface #(
    .COUNTER_WIDTH(8),
      .NUM_WAYS(NUM_WAYS),
      .DATA_WIDTH(DATA_WIDTH),
      .BLOCK_SIZE(BLOCK_SIZE),
      .ADDRESS_WIDTH(ADDRESS_WIDTH)
  ) wayIfs[NUM_WAYS](); 

  virtual WayInterface.master wayIfs_master[NUM_WAYS];
  
  // ------------------------------------------------------
  // Instantiate DUT Cache Data Fetcher
  // ------------------------------------------------------
  CacheDataFetcher #(
    .NUM_WAYS(NUM_WAYS),
    .DATA_WIDTH(DATA_WIDTH)
  ) fetcherInst(
    .wayIfs(wayIfs),
    .CacheDataFetcherIf(cacheDataFetcherIf)
  );
  
  generate
    for (genvar gi = 0; gi < NUM_WAYS; gi++) begin : bind_modports
      initial begin
        wayIfs_master[gi] = wayIfs[gi].master;
      end
    end
  endgenerate
  

  
  always #5 clk = ~clk;
  
  initial begin
    
    
    
    CacheFetchTest test = new();
    test.populateArray();




    fetcherIfMaster = cacheDataFetcherIf.master;
    fetcherIfSlave  = cacheDataFetcherIf.slave;
    clk = 0;
    reset_n = 0; // trigger reset
    #2;
    reset_n = 1;
    #2;


    for (j = 0; j < NUM_WAYS; j++) begin
      wayIfs_master[j].dataOut = test.testData[j]; // drive test data through interface as if ways.  
  	end

    
    
    for (i = 0; i < NUM_WAYS; i++) begin
      fetcherIfMaster.targetWay = 1'b1 << i;
      #1;
      assert(fetcherIfSlave.dataOut == test.testData[i])
        $display("Success: i=%0d, expected=%x, got=%x", i, test.testData[i], fetcherIfSlave.dataOut);
      else
        $fatal("FAIL: i=%0d, expected=%x, got=%x", i, test.testData[i], fetcherIfSlave.dataOut);
    end

	
  end
  

endmodule