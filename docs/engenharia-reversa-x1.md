# Mega Man X (SNES) — visão geral de engenharia reversa para a recriação em Godot 4

Alvo: `MegaManXSNESRecomp/roms/Mega Man X (USA) (Rev 1).sfc` (CPU 65816, LoROM).
Destino: este repo (Godot 4). Arquitetura de referência: `mmx8-16bit/docs/arquitetura-migracao-godot4.md` (seções 3–12).

## Fonte e confiabilidade

- **Fonte usada:** anotações DiztinGUIsh do MegaManXSNESRecomp (`symbols/imported_symbols.tsv`,
  `symbols/classification.tsv`), projeto `bogaa/dizProjects` fixado em `b60813ef`. São
  9.374 rótulos (744 rotinas, 3.984 endereços de RAM) e 95% dos bytes da ROM classificados.
- **O REA não decodifica 65816.** As arquiteturas do `open_binary` são 6502/x86/arm/m68k. Ler a
  ROM como 6502 erra a decodificação nos modos de 16 bits, então a ROM não foi aberta no REA.
- **Nomes são inferências** de quem anotou. O próprio upstream chama o trabalho de "work in
  progress". Endereço = observação; nome = hipótese até ser conferido no código.
- `src/gen/*.c` do recomp é o código recompilado, nomeado por endereço. Para ler uma rotina,
  procure o endereço da tabela abaixo nesses arquivos.
- **Ainda desconhecido:** valores numéricos de física (velocidades, gravidade, tempos de dash e
  carga). Estão nos parâmetros das rotinas e ainda não foram extraídos (ver "Próximos passos").

## Laço principal

| Endereço | Rótulo | Papel |
|---|---|---|
| 808168 | `gameLoopNMI` | VBlank: DMA, PPU |
| 8084A1 | `gameLoopIRQ` | IRQ de raster |
| 80997B | `mainGameLoops` | despacho por `b_gameLoop_idx_d2` (7E00D2) / `b_gameSubLoop_idx_d3` |
| 7E0BA6–7 | `w_RNG_00/01` | RNG global (`849086 shuffleGetRNG`) |

Godot 4: `GameManager` com uma máquina de telas no lugar de `gameLoop_idx`.

## Jogador → `Player` + habilidades (seção 4)

Estado em `w_player_action` (7E0BAA), sub-passo em `w_player_do` (7E0BAB). Os índices são pares
(tabela de ponteiros de 16 bits). Isso mapeia 1:1 para os estágios do `NewAbility`.

| Estado SNES | Endereço | Habilidade Godot |
|---|---|---|
| idle_00 / direction_02 | 8182EE / 81839D | `Idle` |
| walk_04 | 818408 | `Walk` |
| acending_06 (`player_initJump` 8195EC) | 818486 | `Jump` |
| decending_08 / landing_0a | 818522 / 818600 | `Fall` |
| dash_14 / dashOut_20 | 81890E / 8189AA | `Dash` (`dashInit_checks` 819777, `cancleDash` 819662, poeira 819C15) |
| wall_12 / wallJump_10 | 81883E / 818718 | `WallSlide` / `WallJump` |
| ladderGrabAir_24, grabLatterGround_28, ladder_2a, exitLadderTop_26 | 818D33… | `Ladder` (não existe no X8) |
| flinch_0e / death_0c | 81865B / 818A4F | `Damage` / `Death` |
| rideArmor_2c | 818E7F | `Ride` |
| door_1a, enterDoor_18, passDoor_1c, idleAwaitBoss_1e | 818BB1… | `Forced` / câmera de porta |
| healthRecover_3e, kneeling_3c, grabByFile_30, stuck_16, animation_2e | 818F58… | `Forced` / cutscene |

Struct do jogador (RAM 7E0BA8–7E0BDD), formato de toda entidade:

| Campo | Endereço | Godot |
|---|---|---|
| xSubPos/xPos, ySubPos/yPos | 0BAC/0BAD, 0BAF/0BB0 | `position` (ponto fixo 8.8 → float) |
| xSubSpd/xSpd, ySubSpd/ySpd | 0BC2/0BC3, 0BC4/0BC5 | `velocity` (px/frame × 60) |
| health / healthCap | 0BCF / 1F9A | vida / vida máxima |
| jumpFlag, BG_colusionMask | 0BD7, 0BD6 | `is_on_floor/wall` |
| invinsCounter | 0BD8 | i-frames |
| curWeapon, bulletCount | 0BDB, 0BDD | `Shot` |
| blaster_chargeTimer/Value/State | 0BFF, 0C02, 0C03 | `Charge` |
| sprFrame, animTimer, sprPal | 0BB7, 0BBB, 0BB9 | `AnimatedSprite2D` + shader de paleta |

Unidade: o SNES roda a 60 Hz, um passo por frame. No Godot, fixe `physics_ticks_per_second = 60` e
copie a lógica por frame. Isso preserva o comportamento sem reajustar valores à mão.

## Armas (seção 5)

- Buster: `mainWeaponBullet_lemonCharged_01`, `…lemonSuperCharge_02`, `…lemonCharged_03` (80F6D0+).
- 8 armas especiais com munição em 7E1F88–7E1F97: Homing (Torpedo), Sting (Chameleon Sting),
  Shild (Rolling Shield), Fire (Fire Wave), Storm (Storm Tornado), Spark (Electric Spark),
  Cutter (Boomerang Cutter), Ice (Shotgun Ice). Versões carregadas: `mainChargeShot_*` (80F71B+).
- **Tabela de dano:** `weaponDamage_index` 86EF37 + `weaponDamage_00..12` (86EF7D–86F199, 30 bytes
  cada = dano por alvo/chefe). É a matriz de fraquezas. Exporte para um `Resource`.
- Hadouken: rótulos `haduken*` (o recomp tem `mmx_hadouken.h`).

## Armaduras, corações e tanques (seção 6)

- `w_player_upgradeMask` 7E1F99: bits de cabeça, corpo, braço e pernas (`PWupgradeBit*`).
  O mesmo tipo de `equip_parts(id)`.
- Corações: `healthUpgradeHealthIncrease` 81EB3A, `check2spawnHealthUpgrade` 81E99D.
- Sub-tanques: `w_player_tankEnergie_01..04` (7E1F83–86), `collectEnergyTank_00` 81E643.
- Cápsulas do Dr. Light: `eventID_4D_lightCapsule`, `capsle*`, `lightningCapsle*`.
- Redução de dano: `healthArmorReduction` 849D28 / `noArmorHealthReduction` 849D50.
- Senha: `passwordTable__00..0B` (7EFFCB+). Codifica chefes, armadura, corações e tanques.
  Serve de modelo de `Savefile`.

## Inimigos e chefes (seção 7)

Toda entidade de fase é um **eventID** (tabela 80F9B6, entradas de 5 bytes). São 113 rótulos e
107 tipos (01–6B), cada um com `_main`/`_state`/`_action`. Um eventID vira uma cena `Enemy` com
habilidades.

- **Chefes Maverick:** 02 chillPingu (Chill Penguin), 08 lunchOctopus (Launch Octopus),
  0A stingCameleon, 0C mammoth (Flame Mammoth), 14 armadillo (Armored Armadillo),
  22 beeBlader*, 31 sparkMandrill, 06 boomerKuwanger, 52/56 stormEagle.
  (*Bee Blader é sub-chefe.) Dano/hitbox: `bossHitDetectLoop` 849B58, `bossHitBoxCheck` 849C0E,
  `bossHUDdamagCalculation` 849E15, `bossesLevelBasedChange` 84AADD.
- **Sigma / Fortaleza:** 32/66 Vile (mech), 68 vile, 6A vileFinalForm, 5B megaTortoise,
  5C–5F rangdaBangda, 60/61 rex (Velguarder/D-Rex), 62 spiderBoss, 64 sigmaHead, 26 velguarderDog.
- **Zero:** 33 zero, 65 zeroStage1. **Ride Armor:** 2F armorSoldir.
- **Inimigos comuns:** hoganmer, slimVolt, flamingle, planty, RT55J, axeMax, rushRoader, crusher,
  roadAttacker, spiky, bombBeen, seaAttacker, gulpferd, madPeker, creeper, amenHopper, angler,
  utubores, deerball, gunVolt, mineCart, moleBorer, batBone, metC15, digLouber, cragMan,
  metalWing, jamminger, hotarion, flamer, tomBot, ladderJadder, skyClaw, rollingGabyool,
  rayBit, snowShooter, igloo…
- **Objetos de fase:** 16 floatPlatform, 18 fallingRocks, 39 conveyor, 3D towerElevator,
  3F slidePlatform, 40 spring, 41 breakableGlass, 42–44 laser, 47 flamePillar, 4C lavaDrip,
  63 prisonCapsule, 3C textBoxFace (diálogo).
- Exemplo de IA documentada: `mandrill_*` (889E2C+: pulo normal, `mandrill_does_wireJump`).
  Use como modelo para o `BossAI` (estado → ação → sub-ação).

## Fases (seção 8)

Highway (intro) + 8 Mavericks + Sigma 1–4. Paletas por fase em `palDat_*_stage_*` (85D180+).
Layout em `sceneMap*` / `blockMap` / `block*`. Spawns em `loadinPoint*` (43 rótulos) =
checkpoints e entradas. Câmera: `w_cam_BG0_SpdMax_plus/minus` (7E1E54/62) = velocidade máxima de
rolagem para o `KinematicCamera`.

Gráficos (677 KB, 64% da ROM) e paletas (290 tabelas `palDat_*`) estão indexados. Os mapas de
tiles precisam de um extrator próprio para o `TileMap` do Godot 4. Na prática, é mais rápido
reaproveitar os rips de sprites e mapas que já existem (Sprites INC, VGMaps) e usar a ROM só
para lógica e números.

## Telas (seção 9)

`stageSelect_*` (869B33+, textos 869C17+), `showArmorMenu` 80C910, `drawHealthMeter` 80D7CE,
`keepTrackOfBossDefeated` 80D917 / `w_bossDefeatInvFlag` 7E1F0C, opções em 7EFFC1+
(`buttonMap_*`, `optionBGM/SFX/MonoStereo`).

## Próximos passos (em ordem)

1. **Extrair a física do X.** Ler em `src/gen/bank01_*.c` as rotinas de
   `player_action_speed_handler` 819934, `player_initJump` 8195EC, `dashInit_checks` 819777 e
   `jumpCheckValues` 818544. Anotar as constantes de velocidade, gravidade e tempos.
   Alternativa: gravar `w_player_xSpd/ySpd` frame a frame no recomp rodando.
2. Exportar `weaponDamage_*` para `res://data/weapon_damage.tres`.
3. Portar Idle/Walk/Jump/Fall/Dash/Wall como `NewAbility` com os números do passo 1.
   Comparar a trajetória com o recomp (60 fps, mesma entrada).
4. Vertical slice: Highway + Bee Blader + Vile.

**Licença:** os nomes, sprites e música são IP da Capcom. A ROM serve de referência de
comportamento. Não distribua bytes da ROM nem assets extraídos.
