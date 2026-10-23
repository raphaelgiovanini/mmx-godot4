# Roteiro: X1 + X2 + X3 num jogo só (chefes, poderes e armaduras)

Meta do dono: jogar os três jogos em um, pelo menos chefes, poderes e armaduras.

## Inventário a extrair

| | X1 | X2 | X3 |
|---|---|---|---|
| Mavericks | Chill Penguin, Spark Mandrill, Armored Armadillo, Launch Octopus, Boomer Kuwanger, Sting Chameleon, Storm Eagle, Flame Mammoth | Wire Sponge, Wheel Gator, Bubble Crab, Flame Stag, Morph Moth, Magna Centipede, Crystal Snail, Overdrive Ostrich | Blizzard Buffalo, Toxic Seahorse, Tunnel Rhino, Volt Catfish, Crush Crawfish, Neon Tiger, Gravity Beetle, Blast Hornet |
| Outros chefes | Vile, Bospider, Rangda Bangda, D-Rex, Velguarder, Sigma | Magna Quartz, X-Hunters (Agile, Serges, Violen), Zero, Neo Sigma, Sigma Virus | Mac, Vile, Bit, Byte, Godkarmachine, Press Disposer, Doppler, Kaiser Sigma |
| Armas | 8 (eventID → `mainWeaponShot_*`, dano `86:EF37`) | 8 (`extract_x_weapons.py` do recomp já cobre a arte) | 8 (idem) |
| Armadura | 4 peças (`w_player_upgradeMask` 7E:1F99) | 4 peças + Giga Crash | 4 peças + 4 chips |
| Itens | 8 corações, 4 sub-tanques | idem | idem + Ride Armors |

## Pipeline que já funciona

1. **Sprites e efeitos:** Mesen 2 sem janela, fundo escondido, script Lua chega ao gameplay e
   captura quadro a quadro (`~/Games/mmx-lab/mesen2/scripts/`). Recorte: `tools/cut_shots.py`.
2. **Números:** desmontar com `tools/dis816.py` (velocidades, tempos, dano). X1 tem nomes
   (DiztinGUIsh); no X2/X3, achar o equivalente pelo padrão de código ou pela RAM (`watch_write.lua`).
3. **RAM útil:** jogador em `0BA8` (X1) / `09D8` (X2, X3); vida +0x27, invencibilidade +0x30,
   contador de carga +0x57, nível da carga +0x5A.

## Achados de carga

- X1: médio 30 f, cheio 100 f, super (braço) 179 f (`81:9869`, `81:98C2`).
- X2: contador sobe em `7E:0A2F`; nível escrito em `08:BC41`/`08:BE1E`.
- X3: médio 20 f (`04:ABE7`), cheio 80 f (`04:AC37`).
- Ainda não achado: o teste da peça de braço do X2/X3 (tiro duplo/triplo). Não está na rotina de
  carga; o próximo passo é observar a criação do tiro carregado (grupo de sprite `$0E`/`$4D`).

## Ordem proposta

1. Inimigos e dano (base para chefes): Enemy + hitbox + tiro do jogador causando dano.
2. Um chefe por jogo como modelo: Chill Penguin (X1), Wire Sponge (X2), Blizzard Buffalo (X3).
   Sprites pelo Mesen; IA pela ROM (X1 tem `eventID_*` nomeados; ex. `mandrill_*` em `88:9E2C`).
3. Armas desses chefes (recebidas ao vencer), com a tabela de fraquezas.
4. Peças de armadura por jogo e cápsulas do Dr. Light.
5. Repetir para os demais chefes.
