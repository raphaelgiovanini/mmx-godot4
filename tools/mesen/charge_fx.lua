-- Aura de carga original: chega ao gameplay (Start até GO), espera T0 frames parado, segura Y por
-- HOLD frames salvando uma captura por frame (charge_NNN). Fundo escondido nas configurações.
local out = os.getenv("OUT")
local go = tonumber(os.getenv("GO"))
local t0 = tonumber(os.getenv("T0") or "300")
local hold = tonumber(os.getenv("HOLD") or "160")
local health = os.getenv("HEALTH") and tonumber(os.getenv("HEALTH"), 16)
local invinc = os.getenv("INVINC") and tonumber(os.getenv("INVINC"), 16)
local f = 0
emu.addEventCallback(function()
  local t = f - go
  local input = {}
  if f < go - (tonumber(os.getenv("QUIET") or "0")) then input.start = (f % 40) < 4 end
  if t >= t0 and t < t0 + hold then input.y = true end
  emu.setInput(input, 0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  f = f + 1
  local t = f - go
  if health and f > go then emu.write(health, 16, emu.memType.snesWorkRam) end
  if invinc and f > go then emu.write(invinc, 60, emu.memType.snesWorkRam) end
  if t >= t0 - 2 and t < t0 + hold then
    local h = io.open(string.format("%s/charge_%03d.png", out, t - t0), "wb"); h:write(emu.takeScreenshot()); h:close()
  end
  if t > t0 + hold + 5 then emu.stop(0) end
end, emu.eventType.endFrame)
