// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary design header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef _VMAC_CELL_H_
#define _VMAC_CELL_H_  // guard

#include "verilated_heavy.h"

//==========

class Vmac_cell__Syms;
class Vmac_cell_VerilatedVcd;


//----------

VL_MODULE(Vmac_cell) {
  public:
    
    // LOCAL SIGNALS
    // Internals; generally not touched by application code
    CData/*0:0*/ testbench__DOT__clk;
    CData/*0:0*/ testbench__DOT__rst;
    SData/*15:0*/ testbench__DOT__a;
    SData/*15:0*/ testbench__DOT__b;
    IData/*31:0*/ testbench__DOT__acc_in;
    IData/*31:0*/ testbench__DOT__acc_out;
    IData/*31:0*/ testbench__DOT__cycle;
    IData/*31:0*/ testbench__DOT__dut__DOT__mult_result;
    
    // LOCAL VARIABLES
    // Internals; generally not touched by application code
    CData/*0:0*/ __VinpClk__TOP__testbench__DOT__clk;
    CData/*0:0*/ __VinpClk__TOP__testbench__DOT__rst;
    CData/*0:0*/ __Vclklast__TOP____VinpClk__TOP__testbench__DOT__clk;
    CData/*0:0*/ __Vclklast__TOP____VinpClk__TOP__testbench__DOT__rst;
    CData/*0:0*/ __Vchglast__TOP__testbench__DOT__clk;
    CData/*0:0*/ __Vchglast__TOP__testbench__DOT__rst;
    CData/*0:0*/ __Vm_traceActivity[1];
    
    // INTERNAL VARIABLES
    // Internals; generally not touched by application code
    Vmac_cell__Syms* __VlSymsp;  // Symbol table
    
    // CONSTRUCTORS
  private:
    VL_UNCOPYABLE(Vmac_cell);  ///< Copying not allowed
  public:
    /// Construct the model; called by application code
    /// The special name  may be used to make a wrapper with a
    /// single model invisible with respect to DPI scope names.
    Vmac_cell(const char* name = "TOP");
    /// Destroy the model; called (often implicitly) by application code
    ~Vmac_cell();
    /// Trace signals in the model; called by application code
    void trace(VerilatedVcdC* tfp, int levels, int options = 0);
    
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval() { eval_step(); eval_end_step(); }
    /// Evaluate when calling multiple units/models per time step.
    void eval_step();
    /// Evaluate at end of a timestep for tracing, when using eval_step().
    /// Application must call after all eval() and before time changes.
    void eval_end_step();
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    
    // INTERNAL METHODS
  private:
    static void _eval_initial_loop(Vmac_cell__Syms* __restrict vlSymsp);
    void _traceDump();void _traceDumpOpen();void _traceDumpClose();public:
    void __Vconfigure(Vmac_cell__Syms* symsp, bool first);
  private:
    static QData _change_request(Vmac_cell__Syms* __restrict vlSymsp);
    static QData _change_request_1(Vmac_cell__Syms* __restrict vlSymsp);
    void _ctor_var_reset() VL_ATTR_COLD;
  public:
    static void _eval(Vmac_cell__Syms* __restrict vlSymsp);
  private:
#ifdef VL_DEBUG
    void _eval_debug_assertions();
#endif  // VL_DEBUG
  public:
    static void _eval_initial(Vmac_cell__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _eval_settle(Vmac_cell__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _initial__TOP__2(Vmac_cell__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _sequent__TOP__1(Vmac_cell__Syms* __restrict vlSymsp);
  private:
    static void traceChgSub0(void* userp, VerilatedVcd* tracep);
    static void traceChgTop0(void* userp, VerilatedVcd* tracep);
    static void traceCleanup(void* userp, VerilatedVcd* /*unused*/);
    static void traceFullSub0(void* userp, VerilatedVcd* tracep) VL_ATTR_COLD;
    static void traceFullTop0(void* userp, VerilatedVcd* tracep) VL_ATTR_COLD;
    static void traceInitSub0(void* userp, VerilatedVcd* tracep) VL_ATTR_COLD;
    static void traceInitTop(void* userp, VerilatedVcd* tracep) VL_ATTR_COLD;
    void traceRegister(VerilatedVcd* tracep) VL_ATTR_COLD;
    static void traceInit(void* userp, VerilatedVcd* tracep, uint32_t code) VL_ATTR_COLD;
} VL_ATTR_ALIGNED(VL_CACHE_LINE_BYTES);

//----------


#endif  // guard
