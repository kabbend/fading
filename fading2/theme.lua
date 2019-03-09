
local theme = {}

theme.iconSize = 24 
theme.size= 19 		-- base font size
theme.color = { 
	black = {0,0,0}, 
	darkblue = {66,66,238}, 
	darkgreen = {0,102,0},   
	darkgrey = {96,96,96} , 
	green = {0,240,0} , 
	grey = { 211, 211, 211} ,
	masked = {220,240,210}, 
  	orange = {255,165,0},   
	purple = {127,0,255}, 
	red = {250,80,80}, 
	selected = {153,204,255}, 
	white = {255,255,255} , 
	} 

theme.fontTitle 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",20)
theme.fontDice 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",90)
theme.fontRound 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",12)
theme.fontSearch 	= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",16)

theme.backgroundImage 	= love.graphics.newImage( "images/background.jpg" )
theme.dicesImage 	= love.graphics.newImage( "images/dices.png" )
--theme.actionImage 	= love.graphics.newImage( "images/action.jpg" )
--theme.storyImage 	= love.graphics.newImage( "images/histoire.jpg" )
theme.iconClose 	= love.graphics.newImage( "icons/close24x24.png" )
theme.iconResize 	= love.graphics.newImage( "icons/minimize24x24.png" )
theme.iconOnTopInactive	= love.graphics.newImage( "icons/layers-1-24x24.png" )
theme.iconOnTopActive 	= love.graphics.newImage( "icons/layers-2-24x24.png" )
theme.iconFullSize 	= love.graphics.newImage( "icons/enlarge24x24.png" )
theme.iconReduce 	= love.graphics.newImage( "icons/reduce24x24.png" )
theme.iconExpand 	= love.graphics.newImage( "icons/expand24x24.png" )
--theme.iconWWWInactive 	= love.graphics.newImage( "icons/wwwblack16x16.png" )
--theme.iconWWWActive	= love.graphics.newImage( "icons/wwwred16x16.png" )
--theme.iconPencil	= love.graphics.newImage( "icons/pencil.png" )
--theme.iconNew		= love.graphics.newImage( "icons/new.png" )
--theme.iconCentre	= love.graphics.newImage( "icons/centre.png" )
--theme.iconStop		= love.graphics.newImage( "icons/stop.png" )
--theme.iconLink		= love.graphics.newImage( "icons/link.png" )
theme.iconWipe		= love.graphics.newImage( "icons/wipe24x24.png" )
theme.iconKill		= love.graphics.newImage( "icons/kill24x24.png" )
theme.iconVisible	= love.graphics.newImage( "icons/eye24x24.png" )
theme.iconInvisible	= love.graphics.newImage( "icons/eyeblocked24x24.png" )
theme.iconSticky	= love.graphics.newImage( "icons/gluecolor24x24.png" )
theme.iconUnSticky	= love.graphics.newImage( "icons/glue24x24.png" )
theme.iconNext		= love.graphics.newImage( "icons/redo24x24.png" )
theme.iconCircle	= love.graphics.newImage( "icons/dashed-circle24x24.png" )
theme.iconSquare	= love.graphics.newImage( "icons/dashed-square24x24.png" )
theme.iconRound		= love.graphics.newImage( "icons/next24x24.png" )
--theme.iconPartialSalve	= love.graphics.newImage( "icons/partialSalve32x32.png" )
--theme.iconPartialTailler= love.graphics.newImage( "icons/partialTailler32x32.png" )
--theme.iconHook		= love.graphics.newImage( "icons/hook32x32.png" )
--theme.iconDanger	= love.graphics.newImage( "icons/danger32x32.png" )
--theme.iconName		= love.graphics.newImage( "icons/name32x32.png" )
--theme.iconTailler	= love.graphics.newImage( "icons/tailler32x32.png" )
--theme.iconSalve		= love.graphics.newImage( "icons/salve32x32.png" )
--theme.iconDefendre	= love.graphics.newImage( "icons/defendre32x32.png" )
--theme.iconDiscerner	= love.graphics.newImage( "icons/discerner32x32.png" )
--theme.iconEtaler	= love.graphics.newImage( "icons/etaler32x32.png" )
--theme.iconDefier	= love.graphics.newImage( "icons/defier32x32.png" )
--theme.iconAider		= love.graphics.newImage( "icons/aider32x32.png" )
--theme.iconNegocier	= love.graphics.newImage( "icons/negocier32x32.png" )
--theme.iconCamp		= love.graphics.newImage( "icons/camp32x32.png" )
--theme.iconRecuperer	= love.graphics.newImage( "icons/recuperer32x32.png" )
--theme.iconNiveau	= love.graphics.newImage( "icons/niveau32x32.png" )
--theme.iconSession	= love.graphics.newImage( "icons/session32x32.png" )
--theme.iconSoupir	= love.graphics.newImage( "icons/soupir32x32.png" )
--theme.iconFail		= love.graphics.newImage( "icons/fail32x32.png" )
--theme.iconPotion	= love.graphics.newImage( "icons/potion32x32.png" )
--theme.iconMagic		= love.graphics.newImage( "icons/magic32x32.png" )
--theme.iconSuccess	= love.graphics.newImage( "icons/success32x32.png" )
theme.iconEditOff	= love.graphics.newImage( "icons/edit24x24.png" )
theme.iconEditOn	= love.graphics.newImage( "icons/editred24x24.png" )
theme.iconSave		= love.graphics.newImage( "icons/save24x24.png" )

--theme.imageRules	= love.graphics.newImage( "images/rules.png" )
theme.bandeau_selected  = love.graphics.newImage( "images/bandeau-selected.png" )
theme.combatBackground  = love.graphics.newImage( "images/combatBackground.png" )

return theme

