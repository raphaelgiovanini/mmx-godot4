# Mega Man X 1-2-3 — remake de fã em Godot 4

> **Jogo feito por fã, sem fins comerciais.** Não é afiliado, endossado nem patrocinado pela Capcom.
> Mega Man, Mega Man X, X, Zero e todos os personagens, nomes, sprites, músicas e sons relacionados
> são marcas e propriedade da **Capcom Co., Ltd.** Este repositório contém só código, ferramentas e
> documentação escritos para o projeto. Nenhuma ROM nem asset dos jogos originais é distribuído aqui.
> Para jogar, você precisa ter as suas próprias cópias legais dos jogos.

Uma homenagem a **Mega Man X**, **X2** e **X3** (SNES) num jogo só. Os originais são a base, não o
limite: a ideia é manter a sensação dos clássicos e melhorar gráficos, tiros e jogabilidade.

## O que já tem

- **X e Zero** jogáveis, com a física medida nas ROMs (pulo, dash, parede, carga).
- **Armaduras peça por peça:** capacete, corpo, braço e pernas da Light (X1), Giga (X2) e Tri (X3),
  misturáveis entre si, mais os chips do X3 e a Gold Armor.
- **24 armas de chefe** do X1, X2 e X3, com energia própria e mapa de fraquezas no menu.
- **Especiais na tecla F:** Hadouken, Shoryuken e Giga Crush.
- **Menu de pausa** com abas de armadura, armas e itens (Heart Tanks e Sub-Tanks).
- **Fase 1: Central Highway** refeita: rodovia à noite com parallax, buracos, checkpoint, 3 tipos de
  inimigo e arena final com o **Chill Penguin** (tabela de dano do X1; ainda sem IA).

Em andamento: IA dos chefes, fases e as demais armas como projéteis de verdade.
O plano está em `docs/roteiro-3-em-1.md`.

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover | Setas | D-pad |
| Pular | S | A |
| Dash | A, C ou Shift | B |
| Atirar (segure para carregar) | D ou X | X |
| Especial / sabre do Zero | F | R3 |
| Trocar arma | TAB/E e Q | RB e LB |
| Menu de armas | W | L3 |
| Trocar buster do X (X1/X2/X3) | B | Select |
| Pausa | Esc, Enter ou P | Start |

## Rodar

Precisa do **Godot 4.7.2** (`godot` no PATH).

```sh
godot --path .                                               # fase 1
godot --headless --path . -s res://tests/physics_test.gd     # física conferida com a ROM
godot --headless --path . -s res://tests/weapons_test.gd     # tiros
godot --headless --path . -s res://tests/stage_test.gd       # fase 1
```

### Assets (não versionados)

Sprites, sons e músicas não estão no repositório. Eles são gerados localmente a partir das suas
próprias cópias dos jogos e de folhas de sprite de referência, com os scripts de `tools/`:

- `tools/export_mmx8_skins.gd`: sprites do X e do Zero (precisa do Godot 3.6 e do projeto mmx8).
- `tools/mesen/`: gravação de tiros e efeitos no emulador Mesen.
- `tools/cut_*.py`: recorte das gravações e das folhas de sprite.

## Documentação

- `docs/fisica.md`: física do X (X1 = X3).
- `docs/engenharia-reversa-x1.md` e `docs/engenharia-reversa-x2.md`: mapas das ROMs.
- `docs/armaduras-e-energia.md`: armaduras, dano recebido e gasto de energia das armas.
- `docs/chefes.md` e `docs/tiros.md`: chefes e tiros.

## Créditos

- **Capcom**: Mega Man X, X2 e X3 e todos os seus personagens e assets.
- **Projetos de recompilação** do X1 e do X2: referência de comportamento.
- **mmx8-16bit**: base dos sprites do X e do Zero.
- **The Spriters Resource**: folhas de sprite de referência (rips de Random Talking Bush e marcosfl).

Se você é detentor de direitos e quer que algo seja removido, abra uma issue.
