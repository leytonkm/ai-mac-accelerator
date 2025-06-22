// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmac_cell.h for the primary calling header

#include "Vmac_cell.h"
#include "Vmac_cell__Syms.h"

//==========

void Vmac_cell::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vmac_cell::eval\n"); );
    Vmac_cell__Syms* __restrict vlSymsp = this->__VlSymsp;  // Setup global symbol table
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
#ifdef VL_DEBUG
    // Debug assertions
    _eval_debug_assertions();
#endif  // VL_DEBUG
    // Initialize
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) _eval_initial_loop(vlSymsp);
    // Evaluate till stable
    int __VclockLoop = 0;
    QData __Vchange = 1;
    do {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Clock loop\n"););
        vlSymsp->__Vm_activity = true;
        _eval(vlSymsp);
        if (VL_UNLIKELY(++__VclockLoop > 100)) {
            // About to fail, so enable debug to see what's not settling.
            // Note you must run make with OPT=-DVL_DEBUG for debug prints.
            int __Vsaved_debug = Verilated::debug();
            Verilated::debug(1);
            __Vchange = _change_request(vlSymsp);
            Verilated::debug(__Vsaved_debug);
            VL_FATAL_MT("testbench.sv", 3, "",
                "Verilated model didn't converge\n"
                "- See DIDNOTCONVERGE in the Verilator manual");
        } else {
            __Vchange = _change_request(vlSymsp);
        }
    } while (VL_UNLIKELY(__Vchange));
}

void Vmac_cell::eval_end_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+eval_end_step Vmac_cell::eval_end_step\n"); );
#ifdef VM_TRACE
    Vmac_cell__Syms* __restrict vlSymsp = this->__VlSymsp;  // Setup global symbol table
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Tracing
    if (VL_UNLIKELY(vlSymsp->__Vm_dumping)) _traceDump();
#endif  // VM_TRACE
}

void Vmac_cell::_eval_initial_loop(Vmac_cell__Syms* __restrict vlSymsp) {
    vlSymsp->__Vm_didInit = true;
    _eval_initial(vlSymsp);
    vlSymsp->__Vm_activity = true;
    // Evaluate till stable
    int __VclockLoop = 0;
    QData __Vchange = 1;
    do {
        _eval_settle(vlSymsp);
        _eval(vlSymsp);
        if (VL_UNLIKELY(++__VclockLoop > 100)) {
            // About to fail, so enable debug to see what's not settling.
            // Note you must run make with OPT=-DVL_DEBUG for debug prints.
            int __Vsaved_debug = Verilated::debug();
            Verilated::debug(1);
            __Vchange = _change_request(vlSymsp);
            Verilated::debug(__Vsaved_debug);
            VL_FATAL_MT("testbench.sv", 3, "",
                "Verilated model didn't DC converge\n"
                "- See DIDNOTCONVERGE in the Verilator manual");
        } else {
            __Vchange = _change_request(vlSymsp);
        }
    } while (VL_UNLIKELY(__Vchange));
}

VL_INLINE_OPT void Vmac_cell::_sequent__TOP__1(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_sequent__TOP__1\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    if (vlTOPp->testbench__DOT__rst) {
        vlTOPp->testbench__DOT__acc_out = 0U;
        vlTOPp->testbench__DOT__dut__DOT__mult_result = 0U;
    } else {
        vlTOPp->testbench__DOT__acc_out = (vlTOPp->testbench__DOT__dut__DOT__mult_result 
                                           + vlTOPp->testbench__DOT__acc_in);
        vlTOPp->testbench__DOT__dut__DOT__mult_result 
            = ((IData)(vlTOPp->testbench__DOT__a) * (IData)(vlTOPp->testbench__DOT__b));
    }
}

void Vmac_cell::_eval(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_eval\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    if ((((IData)(vlTOPp->__VinpClk__TOP__testbench__DOT__clk) 
          & (~ (IData)(vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__clk))) 
         | ((IData)(vlTOPp->__VinpClk__TOP__testbench__DOT__rst) 
            & (~ (IData)(vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__rst))))) {
        vlTOPp->_sequent__TOP__1(vlSymsp);
    }
    // Final
    vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__clk 
        = vlTOPp->__VinpClk__TOP__testbench__DOT__clk;
    vlTOPp->__Vclklast__TOP____VinpClk__TOP__testbench__DOT__rst 
        = vlTOPp->__VinpClk__TOP__testbench__DOT__rst;
    vlTOPp->__VinpClk__TOP__testbench__DOT__clk = vlTOPp->testbench__DOT__clk;
    vlTOPp->__VinpClk__TOP__testbench__DOT__rst = vlTOPp->testbench__DOT__rst;
}

VL_INLINE_OPT QData Vmac_cell::_change_request(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_change_request\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    return (vlTOPp->_change_request_1(vlSymsp));
}

VL_INLINE_OPT QData Vmac_cell::_change_request_1(Vmac_cell__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_change_request_1\n"); );
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    // Change detection
    QData __req = false;  // Logically a bool
    __req |= ((vlTOPp->testbench__DOT__clk ^ vlTOPp->__Vchglast__TOP__testbench__DOT__clk)
         | (vlTOPp->testbench__DOT__rst ^ vlTOPp->__Vchglast__TOP__testbench__DOT__rst));
    VL_DEBUG_IF( if(__req && ((vlTOPp->testbench__DOT__clk ^ vlTOPp->__Vchglast__TOP__testbench__DOT__clk))) VL_DBG_MSGF("        CHANGE: testbench.sv:5: testbench.clk\n"); );
    VL_DEBUG_IF( if(__req && ((vlTOPp->testbench__DOT__rst ^ vlTOPp->__Vchglast__TOP__testbench__DOT__rst))) VL_DBG_MSGF("        CHANGE: testbench.sv:6: testbench.rst\n"); );
    // Final
    vlTOPp->__Vchglast__TOP__testbench__DOT__clk = vlTOPp->testbench__DOT__clk;
    vlTOPp->__Vchglast__TOP__testbench__DOT__rst = vlTOPp->testbench__DOT__rst;
    return __req;
}

#ifdef VL_DEBUG
void Vmac_cell::_eval_debug_assertions() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmac_cell::_eval_debug_assertions\n"); );
}
#endif  // VL_DEBUG
