# README #

### Aide de Jeu Fading Suns (pour le moment) ###

Le repository contient 3 programmes qui fonctionnent ensemble :

- le serveur, sous le repertoire fading2. Le serveur contient aussi l'interface qui tourne sur le PC du MJ, et qui contient la majeure partie des fonctionnalités. Le serveur peut tourner sans les 2 autres.

- le projecteur, sous le repertoire proj2c. Le projecteur est en visibilité des joueurs, depuis un 2nd moniteur du PC serveur, ou bien sur un autre PC. Pour l'instant les connexions reseau sont en UDP, donc plutot adaptées pour un réseau local et plus fragile certainement sur Internet (pas testé)

- le client mobile, sous le repertoire fsmob. Permet d'envoyer et recevoir de courts messages au MJ (pour le moment)

## Prérequis:
- un compilateur/interpreteur Lua
- le moteur graphique LÖVE (love2d)
- pour l'application mobile, le framework Corona SDK (qui permet de développer également en Lua)

Note: l'editeur de texte ZeroBrane Studio a un support natif pour Lua et Love. Corona a son propre IDE

## Configuration
Aucune au moment de l'installation du code.
Le code s'execute pour le moment en ligne de commande, en passant un certain nombre d'options eventuellement.
le lancement se fait depuis le répertoire parent qui contient fading2/ et proj2c/

Serveur:


```
#!c

love fading2 [options] args

[-b|--base baseDirectory] : Path to a base (network) directory, common with projector
[-d|--debug] :              Run in debug mode
[-l|--log] :                Log to file (fading.log) instead of stdout
[-D|--dynamic] :            With FS mobile: Use the port specified by the client to communicate, not the standard one (ie. 12345 by default)
[-a|--ack] :                With FS mobile: Send an automatic acknowledge reply for each message received
[-p|--port port] :          Specify server local port, by default 12345
arg = fadingDirectory :     Path to scenario directory (not absolute, relative to the base directory)
```


## Database configuration
Aucune. Pas de database

## How to run tests
Et bien, directement. L'option --debug (associée à --log sous Windows, qui a la mauvaise idée de ne pas retranscrire les sorties sur stdout directement dans la console, ce qui oblige a les écrire dans un fichier) permet de savoir ce qui se passe. Sous ZeroBrane Studio existe un mode debug pas à pas pour le moteur Löve, mais très lent je trouve (sur ma config) donc pas utilisable en pratique.


## Deployment instructions