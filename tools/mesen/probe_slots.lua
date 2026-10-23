-- Mapeia objetos ativos: em GO+T0, registra o 1º byte de cada bloco de 0x40 entre 0x0900 e 0x1800.
-- Com KILL=a-b (hex), zera o 1º byte desses blocos todo frame depois de GO e fotografa.
local out, go = os.getenv("OUT"), tonumber(os.getenv("GO"))
local quiet = tonumber(os.getenv("QUIET") or "0")
local kill = os.getenv("KILL")
local k0, k1
if kill then k0, k1 = kill:match("(%x+)-(%x+)"); k0, k1 = tonumber(k0, 16), tonumber(k1, 16) end
local f = 0
emu.addEventCallback(function()
  emu.setInput({start = f < go - quiet and (f % 40) < 4}, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  local t = f - go
  if f > go then
    emu.write(tonumber(os.getenv("HEALTH") or "09FF", 16), 16, emu.memType.snesWorkRam)
    if k0 then for a = k0, k1, 0x40 do emu.write(a, 0, emu.memType.snesWorkRam) end end
  end
  if t == 100 then
    local h = io.open(out .. ".txt", "w")
    for a = 0x0918, 0x17D8, 0x40 do
      h:write(string.format("%04X %02X %02X\n", a, emu.read(a, emu.memType.snesWorkRam), emu.read(a + 0x0A, emu.memType.snesWorkRam)))
    end
    h:close()
  end
  if t == 100 or t == 200 then
    local h = io.open(string.format("%s_%d.png", out, t), "wb"); h:write(emu.takeScreenshot()); h:close()
  end
  if t > 200 then emu.stop(0) end
end, emu.eventType.endFrame)
