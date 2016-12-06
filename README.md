# README #

### Aide de Jeu Fading Suns (pour le moment) ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire fading2. Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalites. Le
  serveur peut tourner sans les 2 autres. Tapez 'Left-Control + h' pour avoir la fenêtre d'aide et un résumé des commandes.

- le projecteur, sous le repertoire proj2c. Le projecteur est en visibilite des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC (eventuellement
  connecte a un projecteur video). Le projecteur peut se connecter a un serveur (principal) ou deux serveurs (par exemple un pour le combat tracker, un pour les maps). Il
  faut indiquer les serveurs avec les parametres 'serverip' et 'secondaryserverip' dans le fichier de conf 'pconf.lua'

- le client mobile, sous le repertoire fsmob. Permet d'envoyer et recevoir de courts messages au MJ

## Prerequis:
- Lua
- le moteur graphique LÖVE (love2d, version à partir de 0.10.2)
- pour l'application mobile, le framework Corona SDK (qui permet de developper egalement en Lua)

## Configuration
le lancement se fait depuis le repertoire parent qui contient fading2/ et proj2c/.
Pour le serveur, la configuration se fait dans l'application (fenêtre de setup accessible par 'CTRL+f') ou bien directement dans le fichier de configuration 'fsconf.lua' à la
racine (voir le paragraphe 'Unicode Hell' ci dessous)
Pour le projecteur, la configuration se fait dans le fichier 'pconf.lua'

##Lancement
Serveur
```
#!c
love fading2
```

Projecteur:
```
#!c
love proj2c
```
## Filesystem structure
Le serveur s'appuie sur un répertoire principal qui sert de banque d'images. Il s'attend à une structure comme ci-dessous, et à ce qu'on lui designe un ou deux
repertoires : Base Directory (chemin complet vers la racine de la banque d'images) et Scenario Directory (facultatif, si on souhaite compléter les informations à la
racuine par un sous répertoire particulier, dédié à un scénario ou une session de jeu particulière). S'il est fourni, le Scenario est un chemin *relatif* par
rapport au Base Directory, pas le chemin complet.

```
#!c
base Directory                -- banque globale d'images, de data, de maps. Peut contenir un ou plusieurs repertoires pour stocker des scenarios differents
 !
 +--- data                    -- fichier qui decrit les classes de PNJ ou les PJ (en principe celles qui ne sont pas liees à un scenario donne)
 !
 +--- pawns                   -- repertoire (facultatif) d'images pour les pions (pawns) sur les maps
 !     +--- pawnDefault.jpg   -- image par defaut pour les pions
 !     +--- pawn*.jpg/png     -- sera associe automatiquement à un PJ si le nom matche (sinon, sera stocke comme une image classique)
 !     +--- *.jpg/png         -- sera stocke en memoire et utilisable durant la partie comme une image de pion, à la discretion du MJ
 !                            -- et aussi, sera associe automatiquement à une classe de PNJ si le nom matche avec celui indique dans le fichier data
 !
 +--- scenario Directory      -- repertoire du scenario en cours
       +--- scenario.txt      -- facultatif: texte (structure) associe au scenario Coggle
       +--- scenario.jpg      -- facultatif: image du scenario Coggle
       +--- pawnDefault.jpg   -- image par defaut pour les pions
       +--- pawn*.jpg/png     -- sera associe automatiquement à un PJ si le nom matche (sinon, stocke comme une image classique)
       +--- map*.jpg/png      -- map: sera stockee en memoire et utilisable durant la partie (destinee à être projetee aux joueurs, et porter des pions) 
       +--- *.jpg/png         -- image generale: sera stocke en memoire et utilisable durant la partie comme une image generale (destinee à être projetee aux joueurs) 
       +--- data              -- fichier (facultatif) qui decrit les classes de PNJ ou les PJ (en principe, dedie à un scenario donne).
                              -- peut completer le fichier data general (avec des classes particulières, par exemple)
```

Il faut fournir au moins une image pawnDefault.jpg de pion par defaut. Tous les autres fichiers (images, maps, scenario...) sont facultatifs mais, évidemment,
fortement conseillés.

##Unicode Hell
Le serveur et le projecteur sont basés, pour le moment, sur le partage de fichiers stockés sur un filesystem accessible aux deux (donc potentiellement un filesystem
réseau ou cloud). C'est ainsi que surgit l'enfer d'unicode, en particulier si on mixe une machine OS X et une machine Windows comme serveur et projecteur. 

En effet, Lua/Löve stockent leurs chaines de caractères en UTF8 (plutot safe), mais Windows utilise par défaut un encodage UTF16. 
Cela a deux effets indésirables:
1. Une fois stocké, un filename ne peut pas être passé directement du serveur vers la couche Windows OS tel quel (le nom n'est pas reconnu). On ne peut pas non plus
passer d'un encodage UTF8 vers UTF16, car de toute façon l'appel à io.open() passe par une couche C qui ne le supporte pas. Une solution perenne serait de passer
par une API compatible UTF16, eg. winapi. C'est un travail un peu lourd, et pas vraiment une top priorité. 
En attendant, le serveur et le projecteur - s'ils tournent sous Windows - transforment le filename d'UTF8 vers un code reconnu par le système et safe du point de
vue io.open(): J'ai choisi le codepage 1252 (qui correspond, plus ou moins, à l'Extended ASCII). Cela signifie que l'on supporte uniquement les caractères spéciaux
de ce codepage: C'est largement suffisant pour un usage normal, mais il faut éviter les caractères grecs ou cyrilliques dans les noms de fichier, pour le moment...
2. Au moment de recueillir les noms de fichier (par une commande dir /b en passant par la couche OS), il faut les convertir en UTF8, en positionnant le codepage souhaité (chcp 65001) au moment du lancement de la commande.

Mais l'enfer ne s'arrête pas là. Sous OS X, l'UTF8 est géré en NFD, et sous Windows en NFC. Donc un nom de fichier lu depuis un serveur sous OS X aura un encodage
UTF8 qui, une fois passé au projecteur sous Windows, ne permettra pas de retrouver le fichier d'origine sur le filesystem (ex. le caractère 'é' encodé 45 cc 81 sous
Mac sera vu comme c3 a9 sous windows, donc ne matchera pas en passant par la couche basse io.open()). Pour y remédier, un serveur sous OS X transforme explicitement
les filenames en NFC (via la commande 'iconv').

## Deployment instructions

pour le client mobile, utiliser le menu Build de Corona SDK qui se charge de tout et cree une application .apk (pour android)
