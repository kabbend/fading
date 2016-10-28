# README #

### Aide de Jeu Fading Suns (pour le moment) ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire fading2. Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalités. Le serveur peut tourner sans les 2 autres.

- le projecteur, sous le repertoire proj2c. Le projecteur est en visibilité des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC. 

- le client mobile, sous le repertoire fsmob. Permet d'envoyer et recevoir de courts messages au MJ

## Prérequis:
- un compilateur/interpreteur Lua
- le moteur graphique LÖVE (love2d, version à partir de 0.10.0)
- pour l'application mobile, le framework Corona SDK (qui permet de développer également en Lua)

## Configuration
Aucune au moment de l'installation du code.
Pour le moment le code s'execute pour le moment en ligne de commande, en passant un certain nombre d'options eventuellement.
le lancement se fait depuis le répertoire parent qui contient fading2/ et proj2c/

## Filesystem structure
Le serveur s'attend à une structure comme suit, où l'on désigne les deux répertoires baseDirectory (chemin complet) et fadingDirectory (chemin relatif par rapport au
précédent):

```
#!c
baseDirectory                 -- banque globale d'images, de data, de maps. Peut contenir un ou plusieurs répertoires pour stocker des scénarios différents
 !
 +--- data                    -- fichier (facultatif mais conseillé) qui décrit les classes de PNJ ou les PJ (en principe, pas liés à un scénario donné)
 !
 +--- pawns                   -- répertoire (facultatif) d'images pour les pions (pawns) sur les maps
 !     +--- pawnDefault.jpg   -- image par défaut pour les pions
 !     +--- pawn*.jpg/png     -- sera associé automatiquement à un PJ si le nom matche (sinon, stocké comme une image classique)
 !     +--- *.jpg/png         -- sera stocké en mémoire et utilisable durant la partie comme une image de pion, à la discrétion du MJ
 !                            -- et aussi, sera associé automatiquement à une classe de PNJ si les nom matche avec celui indiqué dans le fichier data
 !
 +--- fadingDirectory         -- répertoire du scénario en cours
       +--- scenario.txt      -- facultatif: texte (structuré) associé au scénario Coggle
       +--- scenario.jpg      -- facultatif: image du scénario Coggle
       +--- pawnDefault.jpg   -- image par défaut pour les pions
       +--- pawn*.jpg/png     -- sera associé automatiquement à un PJ si le nom matche (sinon, stocké comme une image classique)
       +--- map*.jpg/png      -- map: sera stockée en mémoire et utilisable durant la partie (destinée à être projetée aux joueurs, et porter des pions) 
       +--- *.jpg/png         -- image générale: sera stocké en mémoire et utilisable durant la partie comme une image générale (destinée à être projetée aux joueurs) 
       +--- data              -- fichier (facultatif) qui décrit les classes de PNJ ou les PJ (en principe, dédié à un scénario donné).
                              -- peut compléter le fichier data général (avec des classes particulières, par exemple)
```

Il faut fournir au moins un fichier data (les deux peuvent se compléter), et une image pawnDefault.jpg de pion par défaut.

##Ligne de commande
Serveur:

```
#!c

love fading2 [options] args

[-b|--base baseDirectory] : Path to a base (network) directory, common with projector
[-d|--debug] :              Run in debug mode
[-l|--log] :                Log to file (fading.log) instead of stdout
[-a|--ack] :                With FS mobile: Send an automatic acknowledge reply for each message received
[-p|--port port] :          Specify server local port, by default 12345
arg = fadingDirectory :     Path to scenario directory (not absolute, relative to the base directory)
```

projecteur:

```
#!c

love proj2c [options]

[-b|--base baseDirectory] : Path to a base (network) directory, common with server
[-d|--debug] :              Run in debug mode
[-l|--log] :                Log to file (proj.log) instead of stdout
[-i|--ip address] :         server IP 
[-p|--port port] :          server port (default 12345)
```

## How to run tests
Et bien, directement. L'option --debug (associée à --log sous Windows, qui a la mauvaise idée de ne pas retranscrire les sorties sur stdout directement dans la console, ce qui oblige a les écrire dans un fichier) permet de savoir ce qui se passe. Sous ZeroBrane Studio existe un mode debug pas à pas pour le moteur Löve, mais très lent je trouve (sur ma config) donc pas utilisable en pratique.


## Deployment instructions

pour le client mobile, utiliser le menu Build de Corona SDK qui se charge de tout et créé une application .apk (pour android)
