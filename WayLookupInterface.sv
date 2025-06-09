interface WayLookupInterface #(
    parameter int NUM_WAYS = 4,
    parameter int ADDRESS_WIDTH = 32, 
    parameter int BLOCK_SIZE = 32
);

    localparam OFFSET_WIDTH = $clog2(BLOCK_SIZE);
    localparam TAG_WIDTH = ADDRESS_WIDTH - OFFSET_WIDTH;

    logic [TAG_WIDTH - 1:0] tag;
    logic [NUM_WAYS - 1:0]  hitWay;
    logic                   hit, miss;


    modport master ( // controller ouputs tag to lookup module and recieves hit/miss info
        output tag, 
        input hitWay, hit, miss
    );

    modport slave ( // Eviction Policy reads hit / miss data
        input hitWay, hit, miss
    );

    modport internal (
        input tag,
        output hitWay, hit, miss
    );

endinterface