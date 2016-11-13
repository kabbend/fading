# README #

### Aide de Jeu Fading Suns (pour le moment) ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire fading2. Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalites. Le
  serveur peut tourner sans les 2 autres. Tapez 'Left-Control + h' pour avoir la fenêtre d'aide et un résumé des commandes.

- le projecteur, sous le repertoire proj2c. Le projecteur est en visibilite des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC. 

- le client mobile, sous le repertoire fsmob. Permet d'envoyer et recevoir de courts messages au MJ

## Prerequis:
- un compilateur/interpreteur Lua
- le moteur graphique LÖVE (love2d, version à partir de 0.10.0)
- pour l'application mobile, le framework Corona SDK (qui permet de developper egalement en Lua)

## Configuration
Aucune au moment de l'installation du code.
Pour le moment le code s'execute en ligne de commande, en passant un certain nombre d'options eventuellement.
le lancement se fait depuis le repertoire parent qui contient fading2/ et proj2c/

## Filesystem structure
Le serveur s'attend à une structure comme ci-dessous, et à ce qu'on lui designe les deux repertoires baseDirectory (chemin complet) et fadingDirectory (chemin relatif par rapport au precedent):

```
#!c
baseDirectory                 -- banque globale d'images, de data, de maps. Peut contenir un ou plusieurs repertoires pour stocker des scenarios differents
 !
 +--- data                    -- fichier qui decrit les classes de PNJ ou les PJ (en principe celles qui ne sont pas liees à un scenario donne)
 !
 +--- pawns                   -- repertoire (facultatif) d'images pour les pions (pawns) sur les maps
 !     +--- pawnDefault.jpg   -- image par defaut pour les pions
 !     +--- pawn*.jpg/png     -- sera associe automatiquement à un PJ si le nom matche (sinon, sera stocke comme une image classique)
 !     +--- *.jpg/png         -- sera stocke en memoire et utilisable durant la partie comme une image de pion, à la discretion du MJ
 !                            -- et aussi, sera associe automatiquement à une classe de PNJ si le nom matche avec celui indique dans le fichier data
 !
 +--- fadingDirectory         -- repertoire du scenario en cours
       +--- scenario.txt      -- facultatif: texte (structure) associe au scenario Coggle
       +--- scenario.jpg      -- facultatif: image du scenario Coggle
       +--- pawnDefault.jpg   -- image par defaut pour les pions
       +--- pawn*.jpg/png     -- sera associe automatiquement à un PJ si le nom matche (sinon, stocke comme une image classique)
       +--- map*.jpg/png      -- map: sera stockee en memoire et utilisable durant la partie (destinee à être projetee aux joueurs, et porter des pions) 
       +--- *.jpg/png         -- image generale: sera stocke en memoire et utilisable durant la partie comme une image generale (destinee à être projetee aux joueurs) 
       +--- data              -- fichier (facultatif) qui decrit les classes de PNJ ou les PJ (en principe, dedie à un scenario donne).
                              -- peut completer le fichier data general (avec des classes particulières, par exemple)
```

Il faut fournir au moins un fichier data (ils se completent l'un l'autre s'ils sont présents tous les deux), et une image pawnDefault.jpg de pion par defaut. Tous les autres fichiers (images, maps, scenario...) sont facultatifs

##Ligne de commande
Serveur: Les parametres sont donnés dans un fichier de configuration (fading2/fsconf.lua), ou demandés au démarrage si absents

```
#!c
love fading2
```

Projecteur:

```
#!c
love proj2c [options]

[-b|--base baseDirectory] : Path to a base directory, common with server. If no base directory is given, the projector will request
                            full binary mode to the server, ie. meaning that all files will be sent over the network
[-d|--debug] :              Run in debug mode
[-l|--log] :                Log to file (proj.log) instead of stdout
[-i|--ip address] :         server IP 
[-p|--port port] :          server port (default 12345)
```

## Deployment instructions

pour le client mobile, utiliser le menu Build de Corona SDK qui se charge de tout et cree une application .apk (pour android)
