
local theme = {}

theme.iconSize = 20
theme.size= 19 		-- base font size
theme.color = { masked = {210,210,210}, black = {0,0,0}, red = {250,80,80}, darkblue = {66,66,238}, purple = {127,0,255}, 
  orange = {204,102,0},   darkgreen = {0,102,0},   white = {255,255,255} , green = {0,240,0} , darkgrey = {96,96,96} } 
theme.fontTitle 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",20)
theme.fontDice 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",90)
theme.fontRound 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",12)
theme.fontSearch 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",16)
theme.backgroundImage 	= love.graphics.newImage( "images/background.jpg" )
theme.actionImage 	= love.graphics.newImage( "images/action.jpg" )
theme.storyImage 	= love.graphics.newImage( "images/histoire.jpg" )
theme.dicesImage 	= love.graphics.newImage( "images/dices.png" )
theme.iconClose 	= love.graphics.newImage( "icons/close16x16red.png" )
theme.iconResize 	= love.graphics.newImage( "icons/minimize16x16.png" )
theme.iconOnTopInactive	= love.graphics.newImage( "icons/ontop16x16black.png" )
theme.iconOnTopActive 	= love.graphics.newImage( "icons/ontop16x16red.png" )
theme.iconReduce 	= love.graphics.newImage( "icons/reduce16x16.png" )
theme.iconExpand 	= love.graphics.newImage( "icons/expand16x16.png" )

return theme

