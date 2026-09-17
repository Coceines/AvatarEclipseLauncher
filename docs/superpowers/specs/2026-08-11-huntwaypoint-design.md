# Hunt Waypoint — Design

Data: 2026-08-11 · Status: aprovado · Implementado

## Contexto

O servidor Avatar (TheForgottenServer 1.x, em `C:\Users\imfis\Desktop\Avatar-Compraado-server`)
tem hunts customizadas com criaturas de looktype próprio (ex.: "Abelha de barro" = looktype 1247).
O jogador precisa de um módulo que marque no mapa o caminho até a hunt escolhida.

Requisitos do dono do servidor:

- Os dados das hunts (sprite, stats, localização) ficam **no servidor**; o jogador apenas pede.
- A localização da hunt é **configurada na mão** (campo `Location`), sem auto-derivação de spawns.
- O caminho é desenhado **no chão do jogo** (efeito custom criado no object builder, effectid 185)
  **e no minimap** (bolinhas azuis), a cada **3 SQMs**.
- As bolinhas somem quando o jogador **chega perto** ou após **10 minutos** da marcação.
- **Privacidade**: só quem pediu vê o caminho (render 100% client-side).
- A grade do client mostra até **6 hunts por página** (com paginação): sprite, exp e level recomendado.

## Arquitetura

```
[Servidor]                         [Client (otclientv8)]
 data/huntwaypoint/*.lua  ──lib──▶ modules/game_huntwaypoint/
 data/lib/huntWaypoint.lua         huntwaypoint.lua / .otui / .otmod
 data/creaturescripts/…            ├─ janela com grade (6/página)
 data/creaturescripts.xml          ├─ pede "list" / "path:<nome>" (opcode 169)
 data/.../loginLogout/login.lua    └─ renderiza localmente:
                                       • efeito no chão (g_map.addThing, respawn 490ms)
                                       • bolinhas no minimap (widgets ancorados)
```

- **Dados**: o server envia apenas nome, looktype, exp e level na lista. A localização só vai
  para o client que pedir o caminho daquela hunt (`path:`).
- **Path**: calculado no client com `g_map.findPath` (A* sobre tiles + minimap,
  `PathFindAllowNotSeenTiles | PathFindIgnoreCreatures`, complexidade 50000).
  Fallback: linha reta (interpolação) se não houver caminho.
- **Render no chão**: a cada 3 SQMs do caminho, `Effect.create()` + `g_map.addThing(effect, pos)`.
  Efeitos somem sozinhos após a animação → um timer de **490ms** re-spawna (sem empilhar:
  só se o tile não tiver efeito). Só são spawnados a até 22 SQMs do jogador, no mesmo andar.
- **Render no minimap**: um widget `HuntWaypointDot` (imagem `huntdot.png`, 9x9) por ponto,
  ancorado com `minimapWidget:centerInPosition(widget, pos)` — o layout do minimap
  (`UIMapAnchorLayout::update()` no drawSelf) reposiciona todo frame, então os pontos
  acompanham a câmera/zoom automaticamente.
- **Ciclo de vida** (timer 490ms): ponto removido quando o jogador está a ≤1 SQM (Chebyshev)
  ou no fim dos 10 minutos; pontos de outros andares ficam ocultos no minimap e não são
  spawnados no chão.

## Protocolo — opcode 169

| Direção | Buffer | Resposta |
|---|---|---|
| client → server | `list` | server → client `list|nome~looktype~exp~level;nome2~...` |
| client → server | `path:Abelha de barro` | server → client `path|nome~x~y~z` ou `nopath|nome` |

O server também envia `list|...` automaticamente ~1s após o login (hook no `login.lua`).

## Config de hunt (servidor)

Um arquivo `.lua` por hunt em `data/huntwaypoint/`, carregado com `dodirectory` (o TFS deste
servidor não tem `getDirFiles`; `dodirectory` carrega todos os `.lua` da pasta, ordenados):

```lua
HuntWaypoint.register({
  ["Creature name"] = "Abelha de barro",
  ["Creature apparence"] = 1247,
  ["Creature exp"] = 95,
  ["Recomended level"] = "0-15",
  ["Location"] = {x = 446, y = 307, z = 5},
})
```

`Location` aceita o formato copiado do mapa (`{x = ..., y = ..., z = ...}`) como tabela
direta, como string, ou o simples `"446,307,5"` (`HuntWaypoint.parseLocation`).

Observação: o formato acordado em design era `.txt` key=value; na implementação virou `.lua`
por hunt porque o TFS não lista diretórios — `dodirectory` só carrega arquivos `.lua`.
Mesma intenção: um arquivo por hunt, edição simples, sem parsing manual.

## Arquivos

Servidor (`Avatar-Compraado-server`):
- `data/huntwaypoint/abelha_de_barro.lua` (novo, exemplo)
- `data/lib/huntWaypoint.lua` (novo)
- `data/creaturescripts/scripts/huntWaypoint.lua` (novo)
- `data/creaturescripts/creaturescripts.xml` (evento `HuntWaypointOpcode` adicionado)
- `data/creaturescripts/scripts/loginLogout/login.lua` (registro + envio da lista no login)

Client (`Avatar-comprado-client`):
- `modules/game_huntwaypoint/huntwaypoint.lua` (novo)
- `modules/game_huntwaypoint/huntwaypoint.otui` (novo)
- `modules/game_huntwaypoint/huntwaypoint.otmod` (novo)
- `data/images/game/minimap/huntdot.png` (novo, gerado por `tools/make_huntdot.py`)
- `tools/make_huntdot.py` (novo, gerador do PNG)
- `tools/check_lua_balance.py` (novo, checador de sintaxe usado na implementação)

## Constantes ajustáveis (client)

`effectId` (185; testar 184/185), `dotSpacing` (3), `expiryMs` (10 min), `respawnMs` (490),
`removeRadius` (1), `spawnRadius` (22), `maxPathComplexity` (50000).

## Testes manuais

1. Subir o server com a config de exemplo e logar; conferir no console
   `[HuntWaypoint] 1 hunt(s) carregada(s)`.
2. Abrir a janela (botão topbar com `huntfinder.png`); grade deve mostrar a sprite 1247,
   "EXP 95" e "LVL 0-15".
3. Clicar na Abelha de barro → bolinhas azuis no minimap + efeito no chão a cada 3 SQMs.
4. Andar pelo caminho → bolinhas somem ao chegar perto; aguardar 10 min → somem todas.
5. Confirmar que o efeito 185 renderiza (se não, trocar `effectId` para 184).
6. Testar com 7+ hunts → paginação (2 páginas).
