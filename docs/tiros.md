# Tiros do buster — X1, X2 e X3

## Observado no código (dados reais)

Padrão procurado nas três ROMs: `lda #vel ; bit $10 ; bvs +3 ; lda #-vel` (velocidade com sinal pela
direção), seguido de `lda #grupo ; sta $16` (grupo de sprite) e `jsl setSpriteAnim` (`84:8F07` no X1).

| Jogo | Endereço | Velocidade (px/frame) | Grupo de sprite | Interpretação |
|---|---|---:|---|---|
| X1 | 81:A23D | 4,0 | $08 | lemon (`shot_lemon_00`, anotado) |
| X1 | 81:A304 | 6,0 | $0E | carregado (`shot_lemonCharged_00`, anotado) |
| X1 | 81:A4E4 | 6,0 | $08 | a confirmar (médio?) |
| X1 | 81:A5F5 | 5,0 | $0E | a confirmar |
| X2 | 81:85CB | 4,0 | $08 | lemon |
| X2 | 81:868A | 6,0 | $0E | carregado |
| X2 | 81:8863 | 6,0 | $08 | a confirmar (médio / segundo tiro do braço X2?) |
| X3 | 81:88E7 | 4,0 | $08 | lemon |
| X3 | 81:899C | 6,0 | $4D | carregado |
| X3 | 81:8B01 | 6,0 | $08 | a confirmar (médio) |

- Animações: tabela `AF:A000` no X1 (`setSpriteAnim` lê `grupo × 3`). No X2 é `2F:A000` e no X3,
  `3F:8000`, como no `extract_x_weapons.py` do recomp.
- Poses: `8D:8000` (`mainListSprite`) nos três jogos. Cada pose é uma lista de peças `flags, x, y, tile`.
  As poses dos grupos do buster decodificam.

## Ainda não resolvido: tiles e paleta

- Os tiles do lemon (grupo $08) ficam em `0x80`+. Eles não estão na lista de DMA da arma 0.
- No X2, a DMA da arma 0 (`86:9788`) carrega só parte dos tiles do carregado ($0E usa `28–3F`;
  a DMA cobre `28–29, 2F–39, 3C–47`). O resto vem de outra transferência, provavelmente a do jogador.
- Conclusão: extrair a imagem estaticamente vira adivinhação. O caminho confiável é rodar a ROM e
  capturar VRAM, CGRAM e OAM no frame do tiro.

## Sprites capturados no Mesen 2 (resolvido)

Em vez de reconstruir VRAM/paleta lendo a ROM, os tiros foram capturados rodando as três ROMs no
Mesen 2.1.1 (`--testrunner` + Lua, sem janela), com as camadas de fundo escondidas
(`Snes.HideBgLayer1–4`) e a porta 1 como `SnesController`. Scripts em `~/Games/mmx-lab/mesen2/scripts/`
(`capture_buster.lua`: Start até o gameplay, tiro simples, carga de 240 frames, soltar).

- Gameplay: X1 a partir do frame ~1.320 (Highway), X2 ~1.980, X3 ~3.420 (após "READY").
- X2: o X começa ao lado de um chefe; a captura trava a vida (`7E:09FF`) e a invencibilidade
  (`7E:0A08`). É o mesmo deslocamento do X1 (+0x27 e +0x30 a partir do jogador, `09D8` no X2/X3).
- Recorte: `tools/cut_shots.py` (fundo → transparente, só o que está à frente do X).
  Escolha dos quadros: `tools/install_shots.py` → `assets/shots/x1|x2|x3/` (não versionado).
- O tiro simples do X2 não saiu limpo (havia tiros do inimigo); usa o do X1, que tem o mesmo desenho.

Para refazer:

```sh
M=~/Games/mmx-lab/mesen2
python3 tools/cut_shots.py $M/out/buster2_x1 $M/shots/x1 lemon && MAIN=1 python3 tools/cut_shots.py $M/out/buster2_x1 $M/shots/x1 release
MAXX=160 python3 tools/cut_shots.py $M/out/buster4_x2 $M/shots/x2 lemon && MAXX=160 MAIN=1 python3 tools/cut_shots.py $M/out/buster4_x2 $M/shots/x2 release
python3 tools/cut_shots.py $M/out/buster3_x3 $M/shots/x3 lemon && MAIN=1 python3 tools/cut_shots.py $M/out/buster3_x3 $M/shots/x3 release
python3 tools/install_shots.py $M/shots
```

Falta: o tiro médio (soltar no meio da carga), o tiro duplo do braço do X2 e o triplo do X3, que
exigem as peças de armadura ligadas na RAM.
