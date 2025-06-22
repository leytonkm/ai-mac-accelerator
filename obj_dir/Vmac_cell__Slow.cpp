// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmac_cell.h for the primary calling header

#include "Vmac_cell.h"
#include "Vmac_cell__Syms.h"

//==========

VL_CTOR_IMP(Vmac_cell) {
    Vmac_cell__Syms* __restrict vlSymsp = __VlSymsp = new Vmac_cell__Syms(this, name());
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void Vmac_cell::__Vconfigure(Vmac_cell__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-9);
    Verilated::timeprecision(-12);
}

Vmac_cell::~Vmac_cell() {
#ifdef VM_TRACE
    if (VL_UNLIKELY(__VlSymsp->__Vm_dumping)) _traceDumpClose();
#endif  // VM_TRACE
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void Vmac_cell::_initial__TOP__2(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_initial__TOP__2\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Variables
    WData/*127:0*/ __Vtemp1[4];
    // Body
    __Vtemp1[0U] = 0x2e766364U;
    __Vtemp1[1U] = 0x666f726dU;
    __Vtemp1[2U] = 0x77617665U;
    __Vtemp1[3U] = 0x73696d2fU;
    vl_dumpctl_filenamep(true, VL_CVT_PACK_STR_NW(4, __Vtemp1));
    vlSymsp->TOPp->_traceDumpOpen();
    vlTOPp->testbench__DOT__rst = 0U;
    vlTOPp->testbench__DOT__a = 2U;
    vlTOPp->testbench__DOT__b = 5U;
    vlTOPp->testbench__DOT__acc_in = vlTOPp->testbench__DOT__acc_out;
    VL_WRITEF("Final acc_out = %10#\n",32,vlTOPp->testbench__DOT__acc_out);
    VL_FINISH_MT("testbench.sv", 46, "");
    vlTOPp->testbench__DOT__clk = 1U;
    vlTOPp->testbench__DOT__cycle = 0x14U;
}

void Vmac_cell::_eval_initial(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_eval_initial\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__clk 
        = vlTOPp->__VinpClk__TOP__testbench__DOT__clk;
    vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__rst 
        = vlTOPp->__VinpClk__TOP__testbench__DOT__rst;
    vlTOPp->_initial__TOP__2(vlSymsp);
    vlTOPp->__Vm_traceActivity[0U] = 1U;
}

void Vmac_cell::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::final\n"); );
    // Variables
    Vmac_cell__Syms* __restrict vlSymsp = this->__VlSymsp;
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vmac_cell::_eval_settle(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_eval_settle\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vmac_cell::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_ctor_var_reset\n"); );
    // Body
    testbench__DOT__clk = VL_RAND_RESET_I(1);
    testbench__DOT__rst = VL_RAND_RESET_I(1);
    testbench__DOT__a = VL_RAND_RESET_I(16);
    testbench__DOT__b = VL_RAND_RESET_I(16);
    testbench__DOT__acc_in = VL_RAND_RESET_I(32);
    testbench__DOT__acc_out = VL_RAND_RESET_I(32);
    testbench__DOT__cycle = VL_RAND_RESET_I(32);
    testbench__DOT__dut__DOT__mult_result = VL_RAND_RESET_I(32);
    __VinpClk__TOP__testbench__DOT__clk = VL_RAND_RESET_I(1);
    __VinpClk__TOP__testbench__DOT__rst = VL_RAND_RESET_I(1);
    __Vchglast__TOP__testbench__DOT__clk = VL_RAND_RESET_I(1);
    __Vchglast__TOP__testbench__DOT__rst = VL_RAND_RESET_I(1);
    { int __Vi0=0; for (; __Vi0<1; ++__Vi0) {
            __Vm_traceActivity[__Vi0] = VL_RAND_RESET_I(1);
    }}
}
