# README #

### Aide de Jeu RPG ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire server/ . Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalites. Le
  serveur peut tourner sans les 2 autres.

- le projecteur, sous le repertoire proj/ . Le projecteur est en visibilite des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC  ou un raspberry (eventuellement connecte a un projecteur video). Le projecteur scanne le reseau local au demarrage pour se connecter au serveur 

- le client mobile, sous le repertoire mobile/ . Permet d'envoyer et recevoir des messages au MJ, et entre joueurs

## Prerequis:
- Lua pour le developpement
- le moteur graphique LÖVE love2d, version 0.10.x pour le serveur, et 0.9.x ou 0.10.x pour le projecteur (la compatibilite 0.9.x est necessaire pour fonctionner sous raspberry)
- pour l'application mobile, le framework Corona SDK 

## Configuration
le lancement se fait depuis le repertoire parent qui contient server/ et proj/.
Pour le serveur, la configuration se fait dans l'application (fenêtre de setup accessible par 'CTRL+f') ou bien directement dans le fichier de configuration 'sconf.lua' à la racine (voir le paragraphe 'Unicode Hell' ci dessous)
Pour le projecteur, la configuration se fait dans le fichier 'pconf.lua'

## Lancement
Serveur
```
love server 
```

Projecteur:
```
love proj
```
## Filesystem structure
Le serveur s'appuie sur un répertoire principal qui sert de banque d'images. Il s'attend à une structure comme ci-dessous, et à ce qu'on lui designe un ou deux
repertoires : baseDirectory (chemin complet vers la racine de la banque d'images) et scenarioDirectory (facultatif, si on souhaite compléter les informations à la
racine par un sous répertoire particulier, dédié à un scénario ou une session de jeu particulière). S'il est fourni, le scenario est un chemin *relatif* par
rapport au baseDirectory, pas le chemin complet.

```
#!c
baseDirectory                 -- banque globale d'images, de data, de maps. Peut contenir un ou plusieurs repertoires pour stocker des scenarios differents
 !
 +--- data                    -- fichier qui decrit les classes de PNJ ou les PJ (en principe celles qui sont globales au jeu, pas liees à un scenario donne)
 !
 +--- maps/                   -- sous ce repertoire (facultatif) toutes les images sont considerees comme des maps. Idem, elles ne sont pas liees a un scenario donne
 !
 +--- pawns/                  -- repertoire (facultatif) d'images pour les pions (pawns) sur les maps
 !     !
 !     +--- pawnDefault.jpg   -- image par defaut pour les pions
 !     !
 !     +--- pawn*.jpg/png     -- sera associe automatiquement à un PJ si le nom matche (sinon, sera stocke comme une image classique)
 !     !
 !     +--- *.jpg/png         -- sera stocke en memoire et utilisable durant la partie comme une image de pion, à la discretion du MJ
 !                            -- et aussi, sera associe automatiquement à une classe de PNJ si le nom matche avec celui indique dans le fichier data
 !
 +--- scenarioDirectory/      -- repertoire du scenario pour la session 
       !
       +--- map*.jpg/png      -- une map: sera stockee en memoire et utilisable durant la partie
       !
       +--- *.jpg/png         -- une image generale: sera stockee en memoire et utilisable durant la partie comme une image generale (destinee à être projetee aux joueurs) 
       !
       +--- data              -- fichier (facultatif) qui decrit les classes de PNJ ou les PJ dediees a ce scenario, en complement de celui a la racine
       !
       +--- maps/             -- sous ce repertoire (facultatif) toutes les images sont considerees comme des maps. Elles completent celles du repertoire maps a la racine 
       !
       +--- pawns/            -- repertoire (facultatif) d'images pour les pions (pawns) sur les maps, en complement de celui a la racine
```

Il faut fournir au moins une image pawnDefault.jpg de pion par defaut. Tous les autres fichiers (images, maps, scenario...) sont facultatifs mais, évidemment,
fortement conseilles.

## Unicode Hell
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
