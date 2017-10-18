# README #

### Aide de Jeu Fading Suns (pour le moment) ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire fading2. Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalites. Le serveur peut tourner sans les 2 autres. Tapez 'Left-Control + h' pour avoir la fenÃªtre d'aide et un résumé des commandes.

- le projecteur, sous le repertoire proj2c. Le projecteur est en visibilite des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC (eventuellement connecte a un projecteur video). Le projecteur peut se connecter a un serveur (principal) ou deux serveurs (par exemple un pour le combat tracker, un pour les maps). Il faut indiquer les serveurs avec les parametres 'serverip' et 'secondaryserverip' dans le fichier de conf 'pconf.lua'

- le client mobile, sous le repertoire fsmob. Permet d'envoyer et recevoir de courts messages au MJ

## Prerequis:
- Lua
- le moteur graphique LÃ–VE (love2d, version a  partir de 0.10.2)
- pour l'application mobile, le framework Corona SDK (qui permet de developper egalement en Lua)

## Configuration
le lancement se fait depuis le repertoire parent qui contient fading2/ et proj2c/.
Pour le serveur, la configuration se fait dans l'application (fenetre de setup accessible par 'CTRL+f') ou bien directement dans le fichier de configuration 'fsconf.lua' a la racine (voir le paragraphe 'Unicode Hell' ci dessous)
Pour le projecteur, la configuration se fait dans le fichier 'pconf.lua'

##Lancement
Serveur
```
love fading2
```

Projecteur:
```
love proj2c
```

## Filesystem structure
Le serveur s'appuie sur un repertoire principal qui sert de banque d'images. Il s'attend a une structure comme ci-dessous, et a ce qu'on lui designe un ou deux repertoires : Base Directory (chemin complet vers la racine de la banque d'images) et Scenario Directory (facultatif, si on souhaite completer les informations a la racine par un sous repertoire particulier, dedie a un scenario ou une session de jeu particuliere). S'il est fourni, le Scenario est un chemin *relatif* par
rapport au Base Directory, pas le chemin complet.

```
base Directory                -- banque globale d'images, de data, de maps. Peut contenir un ou plusieurs repertoires pour stocker des scenarios differents
 !
 +--- data                    -- fichier qui decrit les classes de PNJ ou les PJ (en principe celles qui ne sont pas liees Ã  un scenario donne)
 !
 +--- pawns                   -- repertoire (facultatif) d'images pour les pions (pawns) sur les maps
 !     +--- pawnDefault.jpg   -- image par defaut pour les pions
 !     +--- pawn*.jpg/png     -- sera associe automatiquement Ã  un PJ si le nom matche (sinon, sera stocke comme une image classique)
 !     +--- *.jpg/png         -- sera stocke en memoire et utilisable durant la partie comme une image de pion, Ã  la discretion du MJ
 !                            -- et aussi, sera associe automatiquement Ã  une classe de PNJ si le nom matche avec celui indique dans le fichier data
 !
 +--- scenario Directory      -- repertoire du scenario en cours
       +--- scenario.txt      -- (obsolete) texte (structure) associe au scenario Coggle
       +--- scenario.jpg      -- (obsolete) image du scenario Coggle                    
       +--- scenario.mm       -- facultatif: scenario au format XML freemind (.mm)
       +--- pawnDefault.jpg   -- image par defaut pour les pions
       +--- pawn*.jpg/png     -- sera associe automatiquement Ã  un PJ si le nom matche (sinon, stocke comme une image classique)
       +--- map*.jpg/png      -- map: sera stockee en memoire et utilisable durant la partie (destinee a etre projetee aux joueurs, et porter des pions) 
       +--- *.jpg/png         -- image generale: sera stocke en memoire et utilisable durant la partie comme une image generale (destinee Ã  Ãªtre projetee aux joueurs) 
       +--- data              -- fichier (facultatif) qui decrit les classes de PNJ ou les PJ (en principe, dedie Ã  un scenario donne).
                              -- peut completer le fichier data general (avec des classes particulieres, par exemple)
```

Il faut fournir au moins une image pawnDefault.jpg de pion par defaut. Tous les autres fichiers (images, maps, scenario...) sont facultatifs mais, evidemment, fortement conseilles.

##Unicode Hell
Le serveur et le projecteur sont bases, pour le moment, sur le partage de fichiers stockes sur un filesystem accessible aux deux (donc potentiellement un filesystem reseau ou cloud). C'est ainsi que surgit l'enfer d'unicode, en particulier si on mixe une machine OS X et une machine Windows comme serveur et projecteur. 

En effet, Lua/Love stockent leurs chaines de caracteres en UTF8 (plutot safe), mais Windows utilise par defaut un encodage UTF16. 
Cela a deux effets indÃ©sirables:
1. Une fois stocke, un filename ne peut pas etre passe directement du serveur vers la couche Windows OS tel quel (le nom n'est pas reconnu). On ne peut pas non plus passer d'un encodage UTF8 vers UTF16, car de toute facon l'appel a io.open() passe par une couche C qui ne le supporte pas. Une solution perenne serait de passer
par une API compatible UTF16, eg. winapi. C'est un travail un peu lourd, et pas vraiment une top priorite. 
En attendant, le serveur et le projecteur - s'ils tournent sous Windows - transforment le filename d'UTF8 vers un code reconnu par le systeme et safe du point de
vue io.open(): J'ai choisi le codepage 1252 (qui correspond, plus ou moins, Ã  l'Extended ASCII). Cela signifie que l'on supporte uniquement les caracteres speciaux
de ce codepage: C'est largement suffisant pour un usage normal, mais il faut eviter les caracteres grecs ou cyrilliques dans les noms de fichier, pour le moment...
2. Au moment de recueillir les noms de fichier (par une commande dir /b en passant par la couche OS), il faut les convertir en UTF8, en positionnant le codepage souhaite (chcp 65001) au moment du lancement de la commande.

Mais l'enfer ne s'arrete pas la . Sous OS X, l'UTF8 est gere en NFD, et sous Windows en NFC. Donc un nom de fichier lu depuis un serveur sous OS X aura un encodage
UTF8 qui, une fois passe au projecteur sous Windows, ne permettra pas de retrouver le fichier d'origine sur le filesystem (ex. le caractere encode 45 cc 81 sous
Mac sera vu comme c3 a9 sous windows, donc ne matchera pas en passant par la couche basse io.open()). Pour y remedier, un serveur sous OS X transforme explicitement
les filenames en NFC (via la commande 'iconv').

## Deployment instructions

pour le client mobile, utiliser le menu Build de Corona SDK qui se charge de tout et cree une application .apk (pour android)
