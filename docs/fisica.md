# Física do jogador — X1 e X3

## Observado

- X1: a tabela `86:B9B1` (`player_xSpd_action` / `player_ySpd_action` nas anotações DiztinGUIsh) é lida por
  `player_action_speed_handler` (`81:9934`). Cada entrada tem 6 bytes:
  `xSpd` (s16), `ySpd` (s16), `grav` (u8), mais um byte desconhecido.
  O índice é `3 × w_player_action`, e os estados são pares, então o passo é de 6 bytes por estado/2.
- X3: a mesma rotina (padrão `lda tbl,x / bit / bvs / eor #$FFFF / inc / sta $1A / lda tbl+2,x / sta $1C`)
  aparece em `84:AF74`, lendo `86:B272`. As linhas 00–1F são **idênticas byte a byte** às do X1.
  A partir de 0x20 já são outros dados, e as duas tabelas divergem.
- Unidade: 1/256 px por frame, a 60 frames por segundo. `grav` é somada a `ySpd` a cada frame
  (64 = 0,25 px/frame²). `ySpd` positivo = para cima.

Comandos usados (reproduzíveis):

```sh
python3 tools/dis816.py "<X1>.sfc" 819934   # handler do X1
python3 tools/dis816.py "<X3>.sfc" 84AF60   # handler do X3
```

## Valores (iguais no X1 e no X3)

| Linha | xSpd | ySpd | grav | Interpretação (inferida pelo valor, a confirmar no código) |
|---|---:|---:|---:|---|
| 01 | 256 (1,000) | 0 | 0 | passo de 1 px/frame (andar curto / empurrão) |
| 02 | 376 (1,469) | 0 | 0 | **andar** |
| 03 | 0 | 1363 (5,324) | 64 | **pulo** (vertical) |
| 06 | 0 | 768 (3,000) | 64 | pulo curto / quique |
| 07 | −138 (−0,539) | 512 (2,000) | 64 | impulso do **wall jump** (afasta da parede) |
| 08 | 376 (1,469) | 1363 (5,324) | 64 | pulo andando |
| 09 | 256 (1,000) | −512 (−2,000) | 0 | **deslizar na parede** (desce 2 px/frame) |
| 0A | 885 (3,457) | 0 | 0 | **dash** |
| 15 | 0 | 376 (1,469) | 0 | **escada** |
| 17, 1B | −138 | 512 | 64 | variações do wall jump |
| 1E | 456 (1,781) | 376 | 152 | desconhecido (byte 5 = 1) |
| 1F | 376 | 376 | 120 | desconhecido (byte 5 = 1) |

## Conclusão e o que falta

- **A base da física do X3 é a do X1.** O que muda a sensação no X3 está no código, não nesta tabela:
  dash no ar e "wall dash" (armadura), hyper chip, Zero jogável, Ride Armors e a velocidade máxima de
  queda, entre outros.
- O X3 tem imediatos de velocidade espalhados nos banks 83/84 (`lda #$0178` em `83:9842…`,
  `#$0375` em `83:A21B…`, `#$0553` em `83:9939…`). É preciso desmontar esses pontos para achar os
  movimentos exclusivos do X3 (dash no ar, wall dash e o dash do Zero).
- Ainda não medido: a velocidade máxima de queda (cap de `ySpd`), o tempo de dash em frames e o
  tempo de carga do buster.
