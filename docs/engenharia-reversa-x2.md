# Mega Man X2 (SNES) — estado da engenharia reversa

Alvo: `MegaManX2Recomp/mmx2.sfc` (USA). CPU 65816 + coprocessador **Cx4** (Capcom), que faz os
wireframes, as rotações e parte dos chefes. Ver `MegaManX2Recomp/docs/CX4.md`.

## Fonte e cobertura

- As anotações DiztinGUIsh do X2 (bogaa/dizProjects `b60813ef`) têm **um único rótulo**
  (`Emulation_RESET`). Há 32.462 instruções identificadas e 4,62% dos bytes classificados.
  Não existe um mapa nomeado como o do X1.
- O REA não decodifica 65816 (mesma limitação do X1).
- O X2 reaproveita o motor do X1: mesmo modelo de entidades, struct de jogador em RAM e estados
  com índice par. **Isso é inferência e precisa ser conferido.** Caminho: comparar as rotinas do
  X1 já nomeadas com as do X2 por padrão de bytes e de chamadas, depois portar os nomes.

## O que muda em relação ao X1 (jogabilidade conhecida)

- Dash no ar (pernas da armadura do X2) e Giga Crash (corpo).
- Chefes X-Hunters (Agile, Serges, Violen) e as peças do Zero.
- 8 Mavericks novos (Wire Sponge, Wheel Gator, Bubble Crab, Flame Stag, Morph Moth,
  Magna Centipede, Crystal Snail, Overdrive Ostrich) e as armas deles.
- Ride Chaser (moto) e novas Ride Armors.

## Próximos passos

1. Portar os rótulos do X1 para o X2 nas rotinas equivalentes, começando pelos estados do jogador
   e pela tabela de eventIDs.
2. Depois, os mesmos passos do X1: física, tabela de dano, IA dos chefes.
