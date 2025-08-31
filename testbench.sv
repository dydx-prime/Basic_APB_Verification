// top level Test module
// includes env components and sequences files

import uvm_pkg::*;
`include "uvm_macros.svh"

// files
`include "apb_if.svh"
`include "apb_rw.svh"
`include "apb_driver_seq_mon.svh"
`include "apb_agent_env_config.svh"
`include "apb_sequences.svh"
`include "apb_test.svh"

module test;
  
  logic pclk;
  logic [31:0] paddr;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] prdata;
  logic [31:0] pwdata;

  initial begin
    pclk = 0;
  end

  // generate clock
  always begin
    #10 pclk = ~pclk;
  end

  // instantiation of physical interface for APB interface
  apb_if apb_if(.pclk(pclk));

  initial begin
    // physical interface is passed to test top, which passes it down to env->agent->driver/sequencer/monitor
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "vif", apb_if);
    // test run called
    run_test("apb_base_test");
  end

  endmodule
