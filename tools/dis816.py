#!/usr/bin/env python3
"""Desmonta 65816 de uma ROM LoROM a partir de um endereço, rastreando REP/SEP (flags M/X).

Usa o decodificador do snesrecomp (../MegaManXSNESRecomp/snesrecomp/recompiler/snes65816.py).
Uso: dis816.py <rom.sfc> <endereço hex, ex. 8195EC> [n_instruções=40] [m=1] [x=1]
Para ao achar RTS/RTL/RTI. Não segue saltos: é para ler uma rotina, não para mapear a ROM.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../../MegaManXSNESRecomp/snesrecomp/recompiler"))
import snes65816 as s  # noqa: E402

MODES = {name: getattr(s, name) for name in dir(s) if name.isupper() and isinstance(getattr(s, name), int)}
MODE_NAME = {v: k for k, v in MODES.items()}


def fmt(insn, m, x):
    mode = MODE_NAME.get(insn.mode, "?")
    o = insn.operand
    w = 2 if insn.length == 2 else 4
    return {
        "IMM": f"#${o:0{w}X}", "DP": f"${o:02X}", "DP_X": f"${o:02X},x", "DP_Y": f"${o:02X},y",
        "ABS": f"${o:04X}", "ABS_X": f"${o:04X},x", "ABS_Y": f"${o:04X},y",
        "LONG": f"${o:06X}", "LONG_X": f"${o:06X},x", "REL": f"${o:04X}", "REL16": f"${o:04X}",
        "INDIR": f"(${o:04X})", "INDIR_X": f"(${o:04X},x)", "INDIR_Y": f"(${o:02X}),y",
        "INDIR_L": f"[${o:02X}]", "INDIR_LY": f"[${o:02X}],y", "INDIR_DPX": f"(${o:02X},x)",
        "DP_INDIR": f"(${o:02X})", "STK": f"${o:02X},s", "STK_IY": f"(${o:02X},s),y",
    }.get(mode, "")


def main():
    rom = s.load_rom(sys.argv[1])
    s.set_rom_mapping(s.detect_rom_mapping(rom))
    addr = int(sys.argv[2], 16)
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    m = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    x = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    bank, pc = addr >> 16, addr & 0xFFFF
    for _ in range(count):
        off = s.rom_offset(bank, pc)
        insn = s.decode_insn(rom, off, pc, bank, m, x)
        if insn is None:
            print(f"{bank:02X}{pc:04X}  ?? ${rom[off]:02X}")
            return
        raw = " ".join(f"{b:02X}" for b in rom[off:off + insn.length])
        print(f"{bank:02X}{pc:04X}  {raw:<12} {insn.mnem.lower()} {fmt(insn, m, x)}")
        if insn.mnem in ("REP", "SEP"):
            on = insn.mnem == "SEP"
            if insn.operand & 0x20: m = int(on)
            if insn.operand & 0x10: x = int(on)
        if insn.mnem in ("RTS", "RTL", "RTI"):
            return
        pc = (pc + insn.length) & 0xFFFF


if __name__ == "__main__":
    main()
