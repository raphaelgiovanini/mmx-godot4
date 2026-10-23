-- Captura todas as armas: chega ao gameplay (Start até GO-QUIET), dá as armas escrevendo a energia
-- (AMMO base, passo STRIDE, valor VAL) e as peças (MASK=valor em MASKADDR), e para cada arma:
-- aperta R (o jogo troca e carrega os gráficos), atira um tiro normal e captura, carrega HOLD frames,
-- solta e captura. Arquivos: w<n>_shot_NN.png e w<n>_charged_NN.png (NN = frame/2 desde o disparo).
local out = os.getenv("OUT")
local go = tonumber(os.getenv("GO"))
local quiet = tonumber(os.getenv("QUIET") or "0")
local ammo = tonumber(os.getenv("AMMO"), 16)
local stride = tonumber(os.getenv("STRIDE") or "2")
local count = tonumber(os.getenv("N") or "8")
local val = tonumber(os.getenv("VAL") or "5C", 16)
local maskaddr = os.getenv("MASKADDR") and tonumber(os.getenv("MASKADDR"), 16)
local mask = tonumber(os.getenv("MASK") or "0F", 16)
local health = os.getenv("HEALTH") and tonumber(os.getenv("HEALTH"), 16)
local invinc = os.getenv("INVINC") and tonumber(os.getenv("INVINC"), 16)
local hold = tonumber(os.getenv("HOLD") or "130")
local t0 = tonumber(os.getenv("T0") or "300")
local SLOT = 40 + 70 + hold + 100
local f = 0

-- fase de cada arma: [0,40) troca com R; [40,110) tiro; [110,110+hold) carga; depois solta
local function phase(t)
  if t < t0 then return nil end
  local w = math.floor((t - t0) / SLOT) + 1
  if w > count + 1 then return nil end  -- +1: a última volta é o buster de novo (controle)
  return w, (t - t0) % SLOT
end

emu.addEventCallback(function()
  local t = f - go
  local input = {}
  if os.getenv("SELECT") then
    -- X1: abertura pulada (1F9B), seleção de fases, MOVES até o chefe, Start confirma.
    input.start = f > 200 and f < 1100 and (f % 150) < 4
    local moves = {}
    for m in string.gmatch(os.getenv("SELECT"), "[^,]+") do moves[#moves + 1] = m end
    for i, m in ipairs(moves) do if f >= 1150 + i * 40 and f < 1154 + i * 40 then input[m] = true end end
    if f >= 1150 + (#moves + 4) * 40 and f < 1154 + (#moves + 4) * 40 then input.start = true end
    if f >= 1150 + (#moves + 6) * 40 and f < 1154 + (#moves + 6) * 40 then input.b = true end
  elseif f < go - quiet then input.start = (f % 40) < 4 end
  local w, p = phase(t)
  local only = tonumber(os.getenv("ONLY") or "")
  -- ONLY=n: só atira com a arma n (as outras só passam com R); cada arma numa execução.
  if w and only and w ~= only then
    if p >= 4 and p < 8 then input.r = true end
    w = nil
  end
  if w then
    if p >= 4 and p < 8 then input.r = true end
    if p >= 40 and p < 42 then input.y = true end
    if p >= 110 and p < 110 + hold then input.y = true end
    -- SECOND=n: aperta de novo n frames depois de soltar (segundo tiro da carga dupla X2/X3).
    -- SECOND="20,45": apertos depois de soltar (2º tiro da carga dupla; sabre guardado no X3).
    for sec in string.gmatch(os.getenv("SECOND") or "", "%d+") do
      local n = tonumber(sec)
      if p >= 110 + hold + n and p < 112 + hold + n then input.y = true end
    end
  end
  emu.setInput(input, 0)
end, emu.eventType.inputPolled)

emu.addEventCallback(function()
  f = f + 1
  local t = f - go
  if f > go then
    -- ENEMIES=a-b: desliga os inimigos nos primeiros 30 frames do gameplay (gravação limpa). Só no
    -- começo: alguns tiros do X3 (Tornado Fang) usam essa faixa e congelariam se zerados sempre.
    if os.getenv("ENEMIES") and t < 30 then
      local e0, e1 = os.getenv("ENEMIES"):match("(%x+)-(%x+)")
      for a = tonumber(e0, 16), tonumber(e1, 16), 0x40 do emu.write(a, 0, emu.memType.snesWorkRam) end
    end
    if health then emu.write(health, 16, emu.memType.snesWorkRam) end
    if invinc then emu.write(invinc, 60, emu.memType.snesWorkRam) end
    -- Energia cheia ao trocar de arma (regravar todo frame zera a carga das armas especiais).
    local _, p = phase(t)
    if t < t0 or p == 0 then
      for i = 0, count - 1 do emu.write(ammo + i * stride, val, emu.memType.snesWorkRam) end
      -- Apaga os projéteis da arma anterior (o Rolling Shield carregado fica para sempre e trava a troca).
      if os.getenv("SLOTS") then
        local base = tonumber(os.getenv("SLOTS"), 16)
        for slot = 0, 7 do emu.write(base + slot * 0x40, 0, emu.memType.snesWorkRam) end
      end
    end
  end
  if os.getenv("SELECT") and f > 150 then
    -- Abertura concluída: X1 1F9B, X2 1FD1, X3 1FD2 (INTRO).
    emu.write(tonumber(os.getenv("INTRO") or "1F9B", 16), 1, emu.memType.snesWorkRam)
    if os.getenv("CHECKPOINT") then emu.write(0x1F81, tonumber(os.getenv("CHECKPOINT")), emu.memType.snesWorkRam) end
  end
  -- POKE="1FB2=80,...": bytes extras gravados desde o boot (ex.: Z-Saber do X no X3).
  if os.getenv("POKE") and f > 60 then
    for a, v in string.gmatch(os.getenv("POKE"), "(%x+)=(%x+)") do emu.write(tonumber(a, 16), tonumber(v, 16), emu.memType.snesWorkRam) end
  end
  -- As peças valem só se estiverem na RAM quando a fase carrega: grava desde o boot.
  if maskaddr and f > 60 then emu.write(maskaddr, mask, emu.memType.snesWorkRam) end
  local w, p = phase(t)
  local only = tonumber(os.getenv("ONLY") or "")
  if w and only and w ~= only then w = nil end
  if w then
    local name
    -- EVERY=1: um quadro por frame (tiro sem tranco); padrão 2 (metade dos arquivos).
    local every = tonumber(os.getenv("EVERY") or "2")
    if p >= 40 and p < 110 and (p - 40) % every == 0 then name = string.format("w%d_shot_%03d", w, (p - 40) // every) end
    if p >= 110 + hold and (p - 110 - hold) % every == 0 then name = string.format("w%d_charged_%03d", w, (p - 110 - hold) // every) end
    if p == 30 then name = string.format("w%d_select", w) end
    if p == 110 + hold - 10 then name = string.format("w%d_hold", w) end
    if os.getenv("DUMPW") and w == tonumber(os.getenv("DUMPW")) and p >= 100 and p % 4 == 0 then name = string.format("dump_%03d", p) end
    if name then local h = io.open(out .. "/" .. name .. ".png", "wb"); h:write(emu.takeScreenshot()); h:close() end
  end
  if os.getenv("LOGP") and w and p >= 105 then
    local ids = {}
    for slot = 0, 7 do
      local base = 0x1228 + slot * 0x40
      if emu.read(base, emu.memType.snesWorkRam) ~= 0 then
        ids[#ids + 1] = string.format("%02X/%02X", emu.read(base + 0x0A, emu.memType.snesWorkRam), emu.read(base + 0x01, emu.memType.snesWorkRam))
      end
    end
    if p % 4 == 0 then
      local h = io.open(os.getenv("LOGP"), "a"); h:write(string.format("w%d p%d cur%02X lvl%04X %s\n", w, p,
        emu.read(0x0BDB, emu.memType.snesWorkRam), emu.read(0x0C03, emu.memType.snesWorkRam) * 256 + emu.read(0x0BFF, emu.memType.snesWorkRam), table.concat(ids, " "))); h:close()
    end
  end
  if os.getenv("LOGX3") and w and p >= 100 and p % 8 == 0 then
    local h = io.open(os.getenv("LOGX3"), "a")
    h:write(string.format("p%d 57=%02X 58=%02X 82=%02X B7=%02X 1FB2=%02X\n", p, emu.read(0x0A2F, emu.memType.snesWorkRam),
      emu.read(0x0A30, emu.memType.snesWorkRam), emu.read(0x0A5A, emu.memType.snesWorkRam), emu.read(0x0A8F, emu.memType.snesWorkRam),
      emu.read(0x1FB2, emu.memType.snesWorkRam))); h:close()
  end
  -- LOGE=arquivo: energia da arma (byte alto + fração, 8.8) antes do tiro, depois do normal e depois do carregado.
  local lw, lp = phase(t)
  if os.getenv("LOGE") and lw and (lp == 3 or lp == 39 or lp == 108 or lp == 200 or lp == SLOT - 1) then
    local h = io.open(os.getenv("LOGE"), "a")
    h:write(string.format("w%d p%d cur%02X sting%02X", lw, lp, emu.read(0x0BDB, emu.memType.snesWorkRam), emu.read(0x0C31, emu.memType.snesWorkRam)))
    for i = 0, count - 1 do
      local a = ammo + i * stride
      h:write(string.format(" %02X.%02X", emu.read(a, emu.memType.snesWorkRam), emu.read(a - 1, emu.memType.snesWorkRam)))
    end
    h:write("\n")
    h:close()
  end
  if t > t0 + SLOT * (count + 1) + 5 then emu.stop(0) end
end, emu.eventType.endFrame)
