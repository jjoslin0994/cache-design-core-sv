interface WriteToCacheInterface #(
  parameter int NUM_WAYS      = 4,
  parameter int DATA_WIDTH    = 32,
);


  logic [NUM_WAYS - 1:0]    targetWay; // one-hot encoding of way to write to
  logic [DATA_WIDTH - 1:0]  dataIn;

  modport slave (
    input targetWay,
    output dataIn
  );

endinterface : WriteToCacheInterface