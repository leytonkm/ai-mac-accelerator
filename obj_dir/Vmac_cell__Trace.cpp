// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vmac_cell__Syms.h"


void Vmac_cell::traceChgTop0(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Variables
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    {
        vlTOPp->traceChgSub0(userp, tracep);
    }
}

void Vmac_cell::traceChgSub0(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    vluint32_t* const oldp = tracep->oldp(vlSymsp->__Vm_baseCode + 1);
    if (false && oldp) {}  // Prevent unused
    // Body
    {
        if (VL_UNLIKELY(vlTOPp->__Vm_traceActivity[0U])) {
            tracep->chgBit(oldp+0,(vlTOPp->testbench__DOT__clk));
            tracep->chgBit(oldp+1,(vlTOPp->testbench__DOT__rst));
            tracep->chgSData(oldp+2,(vlTOPp->testbench__DOT__a),16);
            tracep->chgSData(oldp+3,(vlTOPp->testbench__DOT__b),16);
            tracep->chgIData(oldp+4,(vlTOPp->testbench__DOT__acc_in),32);
            tracep->chgIData(oldp+5,(vlTOPp->testbench__DOT__cycle),32);
        }
        tracep->chgIData(oldp+6,(vlTOPp->testbench__DOT__acc_out),32);
        tracep->chgIData(oldp+7,(vlTOPp->testbench__DOT__dut__DOT__mult_result),32);
    }
}

void Vmac_cell::traceCleanup(void* userp, VerilatedVcd* /*unused*/) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    {
        vlSymsp->__Vm_activity = false;
        vlTOPp->__Vm_traceActivity[0U] = 0U;
    }
}
