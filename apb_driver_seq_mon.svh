// driver, sequencer, & monitor classes defined

`ifndef APB_DRV_SEQ_MON_SV
`define APB_DRV_SEQ_MON_SV

typedef apb_config;
typedef apb_agent;

// master driver class

class apb_master_drv extends uvm_driver#(apb_rw);

  `uvm_component_utils(apb_master_drv)

  virtual apb_if vif;
  apb_config cfg;

  function new(string name, uvm_component parent = null);
    super.new(name,parent);
  endfunction

  // build phase - gets virtual interface from agent or config_db
  function void build_phase(uvm_phase phase);
    apb_agent agent;
    super.build_phase(phase);
    if($cast(agent, get_parent()) && agent != null) begin
      vif = agent.vif;
    end
    else begin
      if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("APB/DRV/NOVIF", "No virtual interface specified for this driver instance")
      end
  end
  endfunction

  // run phase - driver to sequencer API implementation
  // read/write dependent to APB interface
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    this.vif.master_cb.psel <= '0;
    this.vif.master_cb.penable <= '0;

    forever begin
      apb_rw tr;
      @ (this.vif.master_cb);
      seq_item_port.get_next_item(tr);
      @ (this.vif.master_cb);
      uvm_report_info("APB_DRIVER ", $psprintf("Got Transaction %s", tr.convert2string()));
      // APB command decoded - read or write function called
      case (tr.apb_cmd)
        apb_rw::READ: drive_read(tr.addr, tr.data);
        apb_rw::WRITE: drive_write(tr.addr, tr.data);
      endcase
      // handshake done back to sequencer
      seq_item_port.item_done();
    end
  endtask: run_phase

  virtual protected task drive_read(input bit [31:0] addr, output logic [31:0] data);
    this.vif.master_cb.paddr <= addr;
    this.vif.master_cb.pwrite <= '0;
    this.vif.master_cb.psel <= '1;
    @ (this.vif.master_cb);
    this.vif.master_cb.penable <= '1;
    @ (this.vif.master_cb);
    data = this.vif.master_cb.prdata;
    this.vif.master_cb.psel <= '0;
    this.vif.master_cb.penable <= '0;
  endtask: drive_read

  virtual protected task drive_write(input bit [31:0] addr, input bit [31:0] data);
    this.vif.master_cb.paddr <= addr;
    this.vif.master_cb.pwdata <= data;
    this.vif.master_cb.pwrite <= '1;
    this.vif.master_cb.psel <= '1;
    @ (this.vif.master_cb);
    this.vif.master_cb.penable <= '1;
    @ (this.vif.master_cb);
    this.vif.master_cb.psel <= '0;
    this.vif.master_cb.penable <= '0;
  endtask: drive_write

endclass: apb_master_drv

// apb sequencer class - uvm_sequencer is parametirized to apb_rw sequence item

class apb_sequencer extends uvm_sequencer #(apb_rw);
  `uvm_component_utils(apb_sequencer)

  function new(input string name, uvm_component parent=null);
    super.new(name, parent);
  endfunction : new
endclass : apb_sequencer

// apb monitor class
class apb_monitor extends uvm_monitor;
  virtual apb_if.passive vif;

  // analysis port - parameterized to apb_rw transaction
  // monitor writes transaction objects uppon detection on the interface
  uvm_analysis_port#(apb_rw) ap;

  // config class handle
  apb_config cfg;

  `uvm_component_utils(apb_monitor)

  function new (string name, uvm_component parent = null);
    super.new(name, parent);
    // analysis port
    ap = new("ap", this);
  endfunction: new

  // build phase - handle to virtual if from agent/config_db
  virtual function void build_phase(uvm_phase phase);
    apb_agent agent;
    if ($cast(agent, get_parent()) && agent != null) begin
      vif = agent.vif;
    end
    else begin
      virtual apb_if tmp;
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_if", tmp)) begin
        `uvm_fatal("APBB/MON/NOVIF", "No virtual interface specified for this monitor instance")
      end
    vif = tmp;
  end
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin
      apb_rw tr;
      // setup cycle
      do begin
        @ (this.vif.monitor_cb);
      end
      while (this.vif.monitor_cb.psel !== 1'b1 || this.vif.monitor_cb.penable !== 1'b0);

      // transaction object
      tr = apb_rw::type_id::create("tr", this);

      // populate fields based on values seen on interface
      tr.apb_cmd = (this.vif.monitor_cb.pwrite) ? apb_rw::WRITE : apb_rw::READ;
      tr.addr = this.vif.monitor_cb.paddr;

      @ (this.vif.monitor_cb);
      if (this.vif.monitor_cb.penable !== 1'b1) begin
        `uvm_error("APB", "APB protocol violation: SETUP cycle not followed by ENABLE cycle");
      end
      tr.data = (tr.apb_cmd == apb_rw::READ) ? this.vif.monitor_cb.prdata : '0;
      tr.data = (tr.apb_cmd == apb_rw::WRITE) ? this.vif.monitor_cb.pwdata: '0;
      uvm_report_info("APB_MONITOR", $psprintf("Got Transaction %s", tr.convert2string()));
      // write to analysis port
      ap.write(tr);
    end
  endtask: run_phase
endclass: apb_monitor
`endif
