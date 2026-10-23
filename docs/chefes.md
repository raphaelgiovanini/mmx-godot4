# Chefes

## Chill Penguin (X1) — saco de pancadas

- **Captura (Mesen 2):** `select_boss.lua` com `MOVES=right` (seleção: direita = Chill Penguin),
  `CHECKPOINT=2` (força `w_player_checkpoint` 7E:1F81 = corredor das portas do chefe), anda para a
  direita até entrar, vida do X travada (7E:0BCF). A abertura é pulada com `w_intro_levelClearFlag`
  (7E:1F9B = 1). 587 capturas a cada 3 frames, fundo escondido.
- **Recorte:** `tools/cut_boss.py` → 76 poses distintas (`assets/bosses/chill_penguin/poses/`).
  Parado: `pose_015`/`pose_016` → `idle_0`/`idle_1`.
- **Vida:** 32 (padrão dos chefes do X1).
- **Dano (tabela 86:EF37 do X1, linha 08):** simples 1, médio 2, carregado 3, super-carga 3,
  Hadouken 32, Fire Wave 3 (fraqueza), Fire Wave carregado 4, demais armas 1–2.
  O índice da tabela (86:EF37, 20 ponteiros) aponta uma linha por tipo de alvo; colunas = arma
  (00 simples, 01 médio, 03 carregado, 04 Hadouken, 07–0E armas, 10–17 armas carregadas).
- **Ainda não medido:** tempo de invencibilidade do chefe após o acerto (placeholder 30 frames;
  ver `bossHitDetectLoop` 84:9B58).

# Peças de armadura

## X1 (Light Armor) — mapeado

`w_player_upgradeMask` (7E:1F99): `0x01` capacete, `0x02` braço, `0x04` corpo, `0x08` pernas.
Capturadas as 16 combinações (parado e carregando) com `x1_parts.lua` (MASK escrito desde o boot) →
`assets/armor_parts/x1/{idle,idle2,charge,charge2}_NN.png` (NN = máscara). No menu de pausa, Light
Armor + teclas 1–4. Efeitos: pernas liberam o dash, corpo = metade do dano, braço = carregado maior.

## X2 e X3 — a fazer

Mesmo método, falta o endereço da máscara de peças (o equivalente a 7E:1F99) nesses jogos.
