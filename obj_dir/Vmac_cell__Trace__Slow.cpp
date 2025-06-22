// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vmac_cell__Syms.h"


//======================

void Vmac_cell::_traceDump() {
    const VerilatedLockGuard lock(__VlSymsp->__Vm_dumperMutex);
    __VlSymsp->__Vm_dumperp->dump(VL_TIME_Q());
}
void Vmac_cell::_traceDumpOpen() {
    const VerilatedLockGuard lock(__VlSymsp->__Vm_dumperMutex);
    if (VL_UNLIKELY(!__VlSymsp->__Vm_dumperp)) {
        __VlSymsp->__Vm_dumperp = new VerilatedVcdC();
        const char* cp = vl_dumpctl_filenamep();
        trace(__VlSymsp->__Vm_dumperp, 0, 0);
        __VlSymsp->__Vm_dumperp->open(vl_dumpctl_filenamep());
        __VlSymsp->__Vm_dumperp->changeThread();
        __VlSymsp->__Vm_dumping = true;
    }
}
void Vmac_cell::_traceDumpClose() {
    const VerilatedLockGuard lock(__VlSymsp->__Vm_dumperMutex);
    __VlSymsp->__Vm_dumping = false;
    VL_DO_CLEAR(delete __VlSymsp->__Vm_dumperp, __VlSymsp->__Vm_dumperp = NULL);
}
void Vmac_cell::trace(VerilatedVcdC* tfp, int, int) {
    tfp->spTrace()->addInitCb(&traceInit, __VlSymsp);
    traceRegister(tfp->spTrace());
}

void Vmac_cell::traceInit(void* userp, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    if (!Verilated::calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
                        "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->module(vlSymsp->name());
    tracep->scopeEscape(' ');
    Vmac_cell::traceInitTop(vlSymsp, tracep);
    tracep->scopeEscape('.');
}

//======================


void Vmac_cell::traceInitTop(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    {
        vlTOPp->traceInitSub0(userp, tracep);
    }
}

void Vmac_cell::traceInitSub0(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    const int c = vlSymsp->__Vm_baseCode;
    if (false && tracep && c) {}  // Prevent unused
    // Body
    {
        tracep->declBit(c+1,"testbench clk", false,-1);
        tracep->declBit(c+2,"testbench rst", false,-1);
        tracep->declBus(c+3,"testbench a", false,-1, 15,0);
        tracep->declBus(c+4,"testbench b", false,-1, 15,0);
        tracep->declBus(c+5,"testbench acc_in", false,-1, 31,0);
        tracep->declBus(c+7,"testbench acc_out", false,-1, 31,0);
        tracep->declBus(c+6,"testbench cycle", false,-1, 31,0);
        tracep->declBit(c+1,"testbench dut clk", false,-1);
        tracep->declBit(c+2,"testbench dut rst", false,-1);
        tracep->declBus(c+3,"testbench dut a", false,-1, 15,0);
        tracep->declBus(c+4,"testbench dut b", false,-1, 15,0);
        tracep->declBus(c+5,"testbench dut acc_in", false,-1, 31,0);
        tracep->declBus(c+7,"testbench dut acc_out", false,-1, 31,0);
        tracep->declBus(c+8,"testbench dut mult_result", false,-1, 31,0);
    }
}

void Vmac_cell::traceRegister(VerilatedVcd* tracep) {
    // Body
    {
        tracep->addFullCb(&traceFullTop0, __VlSymsp);
        tracep->addChgCb(&traceChgTop0, __VlSymsp);
        tracep->addCleanupCb(&traceCleanup, __VlSymsp);
    }
}

void Vmac_cell::traceFullTop0(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    {
        vlTOPp->traceFullSub0(userp, tracep);
    }
}

void Vmac_cell::traceFullSub0(void* userp, VerilatedVcd* tracep) {
    Vmac_cell__Syms* __restrict vlSymsp = static_cast<Vmac_cell__Syms*>(userp);
    Vmac_cell* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    vluint32_t* const oldp = tracep->oldp(vlSymsp->__Vm_baseCode);
    if (false && oldp) {}  // Prevent unused
    // Body
    {
        tracep->fullBit(oldp+1,(vlTOPp->testbench__DOT__clk));
        tracep->fullBit(oldp+2,(vlTOPp->testbench__DOT__rst));
        tracep->fullSData(oldp+3,(vlTOPp->testbench__DOT__a),16);
        tracep->fullSData(oldp+4,(vlTOPp->testbench__DOT__b),16);
        tracep->fullIData(oldp+5,(vlTOPp->testbench__DOT__acc_in),32);
        tracep->fullIData(oldp+6,(vlTOPp->testbench__DOT__cycle),32);
        tracep->fullIData(oldp+7,(vlTOPp->testbench__DOT__acc_out),32);
        tracep->fullIData(oldp+8,(vlTOPp->testbench__DOT__dut__DOT__mult_result),32);
    }
}
