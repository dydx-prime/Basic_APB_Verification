// APB Interface

`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if(input bit pclk);
  wire [31:0] paddr;
  wire psel;
  wire penable;
  wire pwrite;
  wire [31:0] prdata;
  wire [31:0] pwdata;

  // Master Clocking block, for Drivers
  clocking master_cb @(posedge pclk);
    output paddr, psel, penable, pwrite, pwdata;
    input prdata;
  endclocking: master_cb

  // Slave Clokcing block, for slave BFM's
  clocking slave_cb @(posedge pclk);
    output prdata;
    input paddr, psel, penable, pwrite, pwdata;
  endclocking: slave_cb

  // Monitor Clocking block, for sampling monitor components
  clocking monitor_cb @(posedge pclk);
    input paddr, psel, penable, pwrite, prdata, pwdata;
  endclocking: monitor_cb
  
  // ensures interface visibility for signals & timings
  modport master(clocking master_cb);
  modport slave(clocking slave_cb);
  modport passive(clocking monitor_cb);

endinterface: apb_if

`endif
