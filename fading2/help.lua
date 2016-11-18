
local theme 	= require 'theme'
local Window 	= require 'window'

-- Help stuff
local HelpLog = {
	{"",0,""},
	{"CTRL+H",170,"Help. Ouvre cette fenêtre"},
	{"CTRL+X",170,"Ferme la fenêtre courante"},
	{"CTRL+D",170,"Dialog. Ouvre la fenêtre de dialogue (communication avec les joueurs)"},
	{"CTRL+C",170,"Center. Recentre la fenêtre au milieu de l'écran"},
	{"CTRL+TAB",170,"Passe à la fenêtre suivante"},
	{"CTRL+V",170,"Visible. Rend la Map sélectionnée visible/invisible des joueurs, sur le projecteur"},
	{"CTRL+S",170,"Stick. Active le mode 'sticky' sur la Map sélectionnée, si elle est visible"},
	{"CTRL+U",170,"Unstick. Retire le mode 'sticky' de la Map sélectionnée"},
	{"CTRL+Z",170,"Zoom. Active la maximization/minimization de la Map sélectionnée"},
	{"CTRL+P",170,"Pions. Sur une Map avec des pions, retire tous les pions"},
	{"SHIFT+Mouse",170,"Sur une Map, créé une forme géométrique qui réduit le brouillard de guerre"},
	{"CTRL+Mouse",170,"Sur une Map, définit la taille des pions"},
	{"ALT+Mouse",170,"Sur une Map, définit une zone d'affichage réduite"},
	{"TAB",170,"Pour les Maps, passe du mode Rectangle au mode Cercle pour tracer les brouillards de guerre"},
	{"ESPACE",170,"Change la catégorie de la barre de snapshots, entre images, maps et pions"},
	{"ESC",170,"Cache toutes les fenêtres (ou les restaure)"},
	{"",0,""},
	{": ou = (macbook pro)",300,"Sur une Map, Zoom - ou +"},
	{": ou ! (windows)",300,"Sur une Map, Zoom - ou +"},
	{"",0,""},
	{"Double-click (snapshot image)",300,"L'envoie au projecteur"},
	{"Double-click (snapshot Map)",300, "Ouvre la map"},
	{"Double-click (Snapshot pion)",300,"Associe le pion au personnage sélectionné dans la liste"},
	}

-- Help class
-- a Help is a window which displays some fixed text . it is not zoomable
Help = Window:new{ class = "help" , title = "HELP" }

function Help:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function Help:click(x,y)
  	Window.click(self,x,y)
	end

function Help:draw()
   -- draw window frame
   self:drawBack()
   love.graphics.setFont(theme.fontSearch)
   local W,H=self.layout.W, self.layout.H
   local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
   -- print current help text
   love.graphics.setColor(0,0,0)
   for i=1,#HelpLog do 
	love.graphics.printf( HelpLog[i][1] , zx + 5, zy + (i-1)*20 , self.w )	
	love.graphics.printf( HelpLog[i][3] , zx + HelpLog[i][2], zy + (i-1)*20 , self.w )	
   end
   -- print bar
   self:drawBar()
end

function Help:update(dt) Window.update(self,dt) end

return Help

