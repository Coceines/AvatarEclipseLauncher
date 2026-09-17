SOUNDS DE MAGIA — data/sounds
==============================

O módulo "game_spellsound" toca o som de cada magia lançada pelo
jogador, SOMENTE quando o servidor confirma o cast (cooldown).

COMO ADICIONAR UM SOM
---------------------
1. Coloque o arquivo .ogg dentro da pasta do elemento:
     data/sounds/Agua/   data/sounds/Ar/
     data/sounds/Fogo/   data/sounds/Terra/
   (ou em qualquer subpasta — a varredura é recursiva)

2. O NOME DO ARQUIVO deve ser igual ao NOME DA MAGIA (não importa
   maiúsculas/minúsculas, espaços, underscores ou acentos):

     Magia "Earth Jump"     ->  Earth Jump.ogg   (ou "Earth jump.ogg")
     Magia "Water Heal"     ->  Water Heal.ogg   (ou "Water_Heal.ogg")
     Magia "Fire Whip"      ->  Fire Whip.ogg

COMO O CAST É DETECTADO
-----------------------
O som NÃO toca no clique do botão. Ele só toca quando a magia
ENTRA EM COOLDOWN — ou seja, quando o servidor CONFIRMA o cast:

- COOLDOWN (#m#): o servidor envia a mensagem de cooldown das folds
  (onTextMessage mode 20, formato #m#<id>,<delay> com delay > 0) SOMENTE
  quando a magia casta de verdade e entra em cooldown. Cast que falha
  (cooldown ativo, mana, nível, sem alvo) não atualiza cooldown -> sem
  mensagem -> sem som. Clicou mas falhou -> sem som.

NOTA: o eco de fala (mode 44) NÃO é usado — este servidor ecoa o nome
mesmo quando o cast falha, então ele não serve de confirmação.

CONTROLE
--------
- Janela de Options -> aba "Spell Sounds":
    * ativar/desativar os sons
    * volume (0-100%)

FORMATO
-------
- .ogg (comprimido/qualquer qualidade). Arquivos muito grandes (>100KB)
  não são pré-carregados, mas tocam normalmente sob demanda.

LISTA DE MAGIAS (nomes exatos usados pelo jogo)
-----------------------------------------------
Fogo:  Fire Whip, Fire Recover, Fire Kick, Fire Skyfall, Fire Jump,
       Fire Impulse, Fire Bolt, Fire Cinder, Fire Star, Fire Cannon,
       Fire Wrath, Fire Focus, Fire Lightning, Fire Bomb, Fire Clock,
       Fire Thunderbolt, Fire Meteor, Fire Striker, Fire Overload,
       Fire Explosion, Fire Voltage, Fire Thunderstorm, Fire Discharge,
       Fire Conflagration

Agua:  Water Whip, Water Recover, Water Explosion, Water Heal,
       Water Jump, Water IceSpikes, Water Res, Water Shards, Water Surf,
       Water Cannon, Water Regen, Water BloodControl, Water Punch,
       Water Dragon, Water Rain, Water Bubbles, Water Protect,
       Water IceBolt, Water Flow, Water IceGolem, Water Tsunami,
       Water Clock, Water Blizzard, Water BloodBending

Ar:    Air Ball, Air Recover, Air Burst, Air Run, Air Jump, Air Force,
       Air Gust, Air Gale, Air Boost, Air Fan, Air Wings,
       Air Suffocation, Air Hurricane, Air Tempest, Air Windblast,
       Air Tornado, Air Barrier, Air Trap, Air Doom, Air Bomb,
       Air Windstorm, Air Stormcall, Air Vortex, Air Deflection

Terra: Earth Crush, Earth Recover, Earth Punch, Earth Rock, Earth Jump,
       Earth Pull, Earth Growth, Earth Collapse, Earth Track,
       Earth Petrify, Earth Fury, Earth Control, Earth Leech,
       Earth Smash, Earth Ingrain, Earth Fists, Earth Arena,
       Earth Curse, Earth Quake, Earth Cataclysm, Earth Aura,
       Earth Armor, Earth Lavaball, Earth Metalwall
