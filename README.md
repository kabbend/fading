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

## Dependencies

## Database configuration
Aucune. Pas de database

## How to run tests

## Deployment instructions

