# Armaduras, energia das armas e Chameleon Sting

Pesquisa de 2026-10-21. O que está marcado **ROM** ou **Mesen** foi conferido no jogo original. O
resto vem de wikis de fãs (fontes no fim) e pode estar errado.

## Armaduras dos originais

| Peça | X1 (Light) | X2 (Giga) | X3 (Tri) |
|---|---|---|---|
| Capacete | Quebra blocos com a cabeça | Item Tracer: revela passagens secretas | Não confirmado |
| Corpo | Dano pela metade (**ROM**) | Enche o Giga Crush ao levar dano. Redução: −1 por golpe ou metade (fontes divergem) | Dano pela metade e escudo ao levar golpe |
| Braço | Carga nível 3 (espiral) e permite carregar armas especiais | Carga dupla (dois tiros) | Carregado em cruz |
| Pernas | Dash no chão; sem elas o X do X1 não tem dash | Dash no ar para a frente | Dash no ar para a frente ou para cima |

### Corpo do X1 na ROM

`84:9D28` (rotina de dano, `healthArmorReduction`):

```
849D3C  lda $26        ; dano recebido
849D3E  sta $0000
849D41  lda $1F99      ; máscara das peças
849D44  bit #$04       ; corpo
849D46  beq +          ; sem corpo: dano inteiro
849D48  lsr $0000      ; com corpo: metade...
849D4B  bcc +
849D4D  inc $0000      ; ...arredondando para cima
849D50  lda $0BCF      ; vida
849D56  sbc $0000
```

Só a peça do corpo (bit `04` de `7E:1F99`) reduz o dano. O capacete não reduz.

### Chips do X3

Só um chip por vez:

- **Capacete:** regenera a vida com o X parado e enche os sub-tanques.
- **Corpo:** reduz ainda mais o dano e o escudo dura mais.
- **Braço:** tiro carregado contínuo (Hyper Charge), gastando energia de arma.
- **Pernas:** dois dashes no ar.

**Gold (Hyper Chip):** soma os quatro chips. Ela só aparece se o jogador pegar todos os outros itens e
nenhum chip. A Hyper Charge gasta menos energia e a energia volta mais rápido. Nenhuma fonte diz
quanto a menos.

Nenhuma armadura dos originais reduz o gasto das armas especiais dos chefes. A única economia de
energia é a da Gold, na Hyper Charge.

## Diferenças do nosso jogo (`scripts/player/characters.gd`, `ARMORS`)

1. **Multiplicadores de dano:** `damage` 1,1–1,6 e `charged` 1,5–2,3 não existem nos originais. A
   armadura muda o tipo de carregado, não o dano.
2. **Dano recebido:** `received` 0,45–0,6 vale para a armadura inteira, com valores inventados. O
   original é metade, arredondando para cima, só com a peça do corpo.
3. **Tri e Gold:** pulo duplo a pedido do usuário, no lugar do dash para cima do X3.
4. **X1 sem pernas:** conferir se o nosso X tem dash sem a peça. No original ele não tem.
5. **Fourth e Ultimate** são do X4, fora do escopo X1–X3.

## Energia das armas

A barra tem 28 unidades em formato 8.8. No X1 o byte alto fica em `7E:1F88 + 2·i` e a fração em
`7E:1F87 + 2·i`. O bit `40` do byte alto marca a arma como ganha, e o bit `80` também é flag.

Custo por disparo do X1, **Mesen**: `tools/mesen/weapons.lua` com `LOGE`, energia lida antes do
tiro, depois do normal e depois do carregado. Cada arma foi medida numa execução separada
(`ONLY=n`), porque o Sting carregado trava a troca.

| Arma | Normal | Carregado |
|---|---|---|
| Homing Torpedo | 0,5 | 3,5 |
| Chameleon Sting | 0,5 | 4,5 |
| Rolling Shield | 1 | 3 |
| Fire Wave | 1/16 por frame segurado | 8,625 |
| Storm Tornado | 1 | 2 |
| Electric Spark | 1 | 3 |
| Boomerang Cutter | 1 | 1 |
| Shotgun Ice | 1 | 2,5 |

Comando (ROM `Mega Man X (USA) (Rev 1).sfc`, em `~/Games/mmx-lab/mesen2`):

```
ONLY=<n> SELECT=right SLOTS=1228 OUT=$PWD/out/energy_o<n> GO=2340 T0=60 HOLD=230 N=8 AMMO=1F88 \
MASKADDR=1F99 MASK=0F HEALTH=0BCF LOGE=$PWD/out/energy_o<n>.txt EVERY=35 \
./Mesen.app/Contents/MacOS/Mesen --testrunner "$R/Mega Man X (USA) (Rev 1).sfc" scripts/weapons.lua
```

**X2/X3:** custos de `MmxWeaponsSpend` no recomp (`src/mmx_weapon_combat.c`,
`src/mmx_weapon_*.inc`; 256 = 1 unidade). Exemplos:

- Crystal Hunter 1/2.
- Magnet Mine, Speed Burner, Spin Wheel, Spinning Blade, Frost Shield e Tornado Fang 1/3.
- Sonic Slicer 0,5/2.
- Ray Splasher 1/2,5.

Bubble Splash, Silk Shot, Strike Chain e Triad Thunder gastam por frame ou por peça. No jogo, esses
quatro ficam provisoriamente com 1 no normal e 2 no carregado.

No jogo: `Weapons.COST` e `MAX_ENERGY` em `scripts/player/weapons.gd`, `Player.energy` e
`weapon_energy()`. A energia é do jogador, compartilhada entre X e Zero. Sem energia, a arma não atira.

## Chameleon Sting carregado (X1)

Não é um tiro: deixa o X invencível. Rotina `chargeShot_camaFlash`, `83:9B88`:

- `$37/$38 = 0x01E0`: dura **480 frames (8 s)**, contados em `83:9BDE`.
- `$3A = 6`: troca a paleta a cada **6 frames**, num ciclo de **8 paletas**.
- Flag `7E:0C31 = 2` enquanto ativo. Com ela ligada, **a troca de arma fica travada** (**Mesen**:
  `0BDB` não muda ao apertar R).

Paletas: tabela de cargas `86:8133 + $1A0 + fase` (fases 0, 2 … 14), mesmo método do recomp
(`MmxRenderAssetsStingPalette`). O corpo do X fica nos índices de CGRAM 144–159. A gravação começa
na fase 2: laranja, amarelo, verde, verde-escuro, azul, azul normal, roxo e vermelho.
`tools/sting_palettes.py` grava `sting_0`…`sting_7` em `assets/weapons/palettes.json`.

No jogo: `Player.sting` e `STING_FRAMES`. A paleta passa pelo `SpriteVisual.set_palette`, então vale
para o X, as armaduras e o Zero. `take_damage` e `set_weapon` são bloqueados enquanto o Sting está
ativo. Falta: os brilhinhos rosa que se juntam no X antes do efeito. No Zero, o cabelo também muda de
cor; não conferido no original.

## Tabela de dano do X1 (conferida)

As linhas 05 a 0C de `86:EF7D` são os 8 chefes. Todas as fraquezas batem com o mapa do menu W.
Linha do Chill Penguin (08): Fire Wave 3, Fire Wave carregado 4, Chameleon Sting carregado 0, demais
armas 1.

## Fontes

- [MegaManWiki – Armor Parts](https://megamanwiki.com/wiki/Armor_Parts)
- [MegaManWiki – Second Armor](https://MegaManWiki.com/wiki/Second_Armor)
- [MegaManWiki – Third Armor](https://megamanwiki.com/wiki/Third_Armor)
- [MegaManWiki – Hyper Chip](https://megamanwiki.com/wiki/Hyper_Chip)
- [MegaManWiki – Giga Crush](https://MegaManWiki.com/wiki/Giga_Crush)
- [Armor Parts (Fandom, via BreezeWiki)](https://breezewiki.discard.no/megaman/wiki/Armor_Parts)
- [Giant Bomb – Mega Man X2](https://www.giantbomb.com/mega-man-x2/3030-19801/)
- [HonestGamers – Mega Man X3](https://www.honestgamers.com/guides/mega-man-x3/32/read/710.html)

## Corpo do X2 e do X3 na ROM

**X2 (`88:D981`, `88:DA15`)**, peça do corpo = bit `04` de `7E:1FD0`:
- Dano: `d = max(dano − 1, 1)`; se `d ≥ 5`, `d − 1`. Ex.: 3→2, 6→4, 8→6.
- Giga Crush: 9ª energia de arma (`7E:1FCA`, bits `C000` são flags), máximo `$1C00` = 28 unidades.
  Cada golpe de inimigo (objeto ≥ `$1318`) soma `86:B0E6[$0A]`, quase sempre `$400` = 4 unidades.
  Ao encher toca o som `$18`.
- Não achado: dano do Giga Crush em cada chefe e a duração da pose (placeholders em `player.gd`).

**X3 (`84:CE41`, `84:87FA`)**, peça do corpo = bit `04` de `7E:1FD1`, chip do corpo = bit `40` de `7E:1FD7`:
- Dano: metade, arredondando para baixo (`lsr`, sem `inc`), mínimo 1.
- Escudo em `7E:1FFF`: o 1º golpe marca `$80` (normal) ou `$20` (chip); depois do golpe o escudo
  surge e liga `$40` / `$10`.
  - `$C0` (normal pronto): o golpe seguinte tira mais 1 e limpa `$80` — o escudo se gasta.
  - `$30` (chip): todo golpe tira mais 2, e o escudo não quebra.
  - Os bits só são zerados juntos (`trb #$F0` em `81:8725`), então o escudo normal não volta na mesma vida.
- Gold (Hyper Chip) tem o chip do corpo.
