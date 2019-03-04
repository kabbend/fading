
local theme = require 'theme'
local rpg = require 'rpg'

local unpack = table.unpack or unpack
function color(c) return unpack(theme.color[c]) end
local oldiowrite = io.write
function io.write( data ) if debug then oldiowrite( data ) end end

-- Window class
-- a window is here an object slightly different from common usage, because
-- * a window may have the property to be zoomable, dynamically at runtime. This
--   is not the same as resizable, as its scale then changes (not only its frame)
--   For this reason, the important information about coordinates is not the
--   classical position (x,y) associated to the upper left corner of the window 
--   within the screen coordinate-system, but the point within the window itself,
--   expressed in the window-coordinate system, which is currently displayed at
--   the center of the screen (see the difference?). This point is an invariant
--   when the window zooms in or out.
-- * w and h are respectively width and height of the window, in pixels, but
--   expressed for the window at scale 1 (no zoom in or out). These dimensions
--   are absolute and will not change during the lifetime of the window object,
--   only the scaling factor will change to reflect a bigger (or smaller) object
--   actually drawn on the screen 
-- Notes: Windows are gathered and manipulated thru the mainLayout class 
--

-- timer for button help popup
local lastButton = nil
local lastButtonTimer = 0
local lastButtonTimerDelay = 1

local popupButtonText = {
	close='Ferme la fenêtre courante. Lorsque vous la réouvrirez, la fenêtre réapparaitra au même endroit et avec la même taille',
	eye="Active ou désactive la visibilité de la Carte. Lorsqu'elle est visible, une carte est projetée aux Joueurs en temps réel avec tous les mouvements ou les zooms que vous faites (si vous voulez éviter cela, utilisez l'icone 'glue' qui apparait à gauche de cette icone, pour figer la vue des Joueurs)",
	wipe="Retire tous les personnages morts, s'il y en a, aussi bien dans le combat tracker que sur les cartes",
	kill="Retire tous les pions de toutes les cartes (A utiliser avec précaution)",
	always="Force la fenêtre à l'avant plan",
	fullsize="Affiche la carte à son échelle réelle (souvent supérieure à la taille de l'écran). Si vous réappuyez sur ce bouton, la fenêtre se repositionnera comme elle était initialement. Attention, si la fenêtre n'est pas en mode 'glue', le changement de zoom sera projeté aux Joueurs également.\n Si la carte est trop grande et que vous souhaitez vous concentrer sur une partie seulement, vous pouvez passer en mode 'quad' (quadrilatère) en sélectionnant une zone avec ALT + mouvement de souris",
	scotch="Active ou désactive le mode 'glue'. En mode glue, les mouvements ou zoom que vous faîtes ne sont plus répercutés aux Joueurs (les mouvements des pions, eux, sont toujours visibles).\n Lorsque vous désactivez le mode glue, la carte revient à sa dernière position et zoom connus (c'est à dire, identique à celle que les Joueurs peuvent voir)",
	next="Passe à la vue suivante. Cette fenêtre permet de lister, successivement: Les images générales (paysages, etc.), les cartes, les classes de personnage",
	fog="Determine la forme géométrique (rectangle ou cercle) pour éliminer le brouillard de guerre. On peut tracer une forme en appuyant sur SHIFT + mouvement de souris",
	unquad="Sort du mode 'quad'. Restaure la fenêtre comme elle était auparavant. Cette modification n'est pas visible des Joueurs, puisque ni la position ni le zoom ne changent",
	round="Termine le round en cours. Restaure les actions des Joueurs",
	hook="-reserved-",
	partialT="Donne un resultat aléatoire en Mêlée sur un demi-succès (7-9), pour relancer l'action",
	partialS="Donne un resultat aléatoire à l'Arc sur un demi-succès (7-9), pour relancer l'action",
	danger="Donne aléatoirement un effet environnemental ou un piège",
	potion="Donne une potion aléatoirement",
	magic="Donne un objet magique aléatoirement",
	name="Donne aléatoirement une série de noms de PNJ",
	edit="Mode édition de Map. Permet de saisir, modifier, bouger du texte sur la Map",
	save="Sauvegarde la Map avec son texte, ses Pions, son Fog of War",
	}

-- sink motion
local sinkSteps = 25 
local border = 2

local Window = {class = "window", w = 0, h = 0, mag = 1.0, x = 0, y = 0 , title = "", 	-- base window information and shape
		zoomable = false ,							-- can we change the zoom ?
		buttons = { 'close' },							-- ordered list of buttons (when applicable)
											-- among:
											-- 'close', 'always', 'unquad', 'fulsize', 'kill', 'wipe', 'eye', 'scotch', 'next',
											-- 'fog', 'round', 'partialS', 'partialT', 'potion', 'magic', 'name', 'hook'...
		movable = true ,							-- can we move the window 
	   	sticky = false, stickX = 0, stickY = 0, stickmag = 0 , 			-- FIXME: should be in map ?
		markForClosure = false,							-- event to close the window
		markForSink = false,							-- event to sink (gradually disappear)
	        alwaysOnTop = false, alwaysBottom = false , 				-- force layering
		wResizable = false, hResizable = false, whResizable = false, 		-- resizable for w and h
		widgets = {},								-- list of widgets in the window. Important: Inherited classes from Window
											-- should redeclare this table explicitely, otherwise all will share the same
											-- which is probably not the desired effect.
		layout = nil,								-- layout (although it is also global variable, at least for the moment)
		download = false,							-- download icon ? no by default
	  }

function Window:new( t ) 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.markForSink = false
  new.markForUnsink = false
  new.markForSinkDeltax = 0 -- absolute delta per step (in pixels)
  new.markForSinkDeltay = 0
  new.markForSinkDeltaMag = 0
  new.markForSinkTimer = 0
  new.sinkSteps = 0
  return new
end

function Window:getButtonByPosition(position)
    if (position <= 0 or position > #self.buttons) then return nil end
    return self.buttons[position]
end


function Window:addWidget( widget ) table.insert( self.widgets, widget ); widget.parent = self end
 
-- window to screen, screen to window: transform x,y coordinates within the window from point on screen
function Window:WtoS(x,y) local W,H=self.layout.W, self.layout.H; return (x - self.x)/self.mag + W/2, (y - self.y)/self.mag + H/2 end

-- translate window by dx, dy pixels on screen, with unchanged mag factor 
function Window:translate(dx,dy) self.x = self.x - dx * self.mag; self.y = self.y - dy * self.mag end
	
-- request the window to sink at the given target position tx, ty on the screen, and covering a window
-- of width w on the screen
function Window:sink(tx,ty,w) 
	self.markForSink = true
	self.sinkFinalDisplay = false
	self.restoreSinkX, self.restoreSinkY, self.restoreSinkMag = self.x, self.y, self.mag
	local cx, cy = Window.WtoS(self,self.w/2, self.h/2)
	self.markForSinkDeltax, self.markForSinkDeltay = (tx - cx)/sinkSteps, (ty - cy)/sinkSteps
	local wratio = self.w / w
	self.markForSinkDeltaMag = (wratio - self.mag)/sinkSteps
	self.sinkSteps = 0
	self.markForSinkTimer = 0
	self.layout.sinkInProgress = true
	end
 	

-- request the window to unsink from source position sx, sy at the given target (window) position x,y, with mag factor 
function Window:unsink(sx, sy, sw, x, y, mag) 
	local W,H=self.layout.W, self.layout.H	
	self.markForSink = true
	self.sinkFinalDisplay = true
	local startingmag = self.w / sw
	self.markForSinkDeltaMag = (mag - startingmag) / sinkSteps
	-- where would be the window center on screen at the end ?
	self.mag = mag; self.x = x; self.y = y
	local cx, cy = Window.WtoS(self,self.w/2, self.h/2)
	self.markForSinkDeltax, self.markForSinkDeltay = (cx - sx)/sinkSteps, (cy - sy)/sinkSteps
	-- real starting data
	self.mag = startingmag; 
	self.x = self.w/2; self.y = self.h/2
	Window.translate(self,sx-W/2, sy-H/2) -- we apply the correct translation
	self.sinkSteps = 0
	self.markForSinkTimer = 0
	self.layout:setDisplay(self,true)
	self.layout.sinkInProgress = true
	end

-- return true if the point (x,y) (expressed in layout coordinates system,
-- typically the mouse), is inside the window frame (whatever the display or
-- layer value, managed at higher-level)
function Window:isInside(x,y)
  local W,H=self.layout.W, self.layout.H;
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  return x >= zx and x <= zx + self.w / self.mag and 
  	 y >= zy - theme.iconSize and y <= zy + self.h / self.mag -- iconSize needed here to take window bar into account
end

function Window:zoom( mag ) if self.zoomable then self.mag = mag end end
function Window:move( x, y ) if self.movable then self.x = x; self.y = y end end
function Window:setTitle( title ) self.title = title end

-- drawn upper button bar
function Window:drawBar( )

 local W,H=self.layout.W, self.layout.H 
 -- reserve space for buttons 
 local reservedForButtons = theme.iconSize * #self.buttons

 -- draw bar
 if self == self.layout:getFocus() then love.graphics.setColor(color('selected')) else love.graphics.setColor(color('grey')) end
 local lzx,lzy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
 local zx,zy = lzx, math.max(lzy,theme.iconSize) 
 local margin = 1
 local requiredSize = ((self.w) / self.mag)+2*border;
 local s = 0
 -- print bar tile as many times as required
 love.graphics.setScissor(zx - border, zy - theme.iconSize, requiredSize, theme.iconSize + margin * 2 );
 while s < requiredSize do 
  love.graphics.draw(theme.bandeau_selected , zx - border + s, zy - theme.iconSize );
  s = s + theme.bandeau_selected:getWidth();
 end
 love.graphics.setScissor();

 -- draw icons. Positions are expressed from right to left, 1 is the rightmost one
 love.graphics.setFont(theme.fontRound)
 love.graphics.setColor(255,255,255)

 local position = #self.buttons
 local zxf = math.min(zx + self.w / self.mag, W)

 for i=1,#self.buttons do
   
   -- check that we have enough space to draw the icon. Otherwise don't draw...
   local realx = zxf - position * theme.iconSize + margin
   if realx >= zx then
 
   if self.buttons[i] == 'close' then
   	love.graphics.draw( theme.iconClose, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'always' then
     if self.alwaysOnTop then 	-- always on top, in position 2
 	love.graphics.draw( theme.iconOnTopActive, zxf - position*theme.iconSize+ margin , zy - theme.iconSize+ margin)
     else
 	love.graphics.draw( theme.iconOnTopInactive, zxf - position*theme.iconSize+ margin , zy - theme.iconSize+ margin)
     end
   elseif self.buttons[i] == 'unquad' and self.quad then
   	love.graphics.draw( theme.iconExpand, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'kill' then
   	love.graphics.draw( theme.iconKill, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'wipe' then
   	love.graphics.draw( theme.iconWipe, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'next' then
   	love.graphics.draw( theme.iconNext, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'round' then
   	love.graphics.draw( theme.iconRound, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'hook' then
   	love.graphics.draw( theme.iconHook, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'partialT' then
   	love.graphics.draw( theme.iconPartialTailler, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'partialS' then
   	love.graphics.draw( theme.iconPartialSalve, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'danger' then
   	love.graphics.draw( theme.iconDanger, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'name' then
   	love.graphics.draw( theme.iconName, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'potion' then
   	love.graphics.draw( theme.iconPotion, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'edit' then
	if self:getEditionMode() then
   		love.graphics.draw( theme.iconEditOn, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	else
   		love.graphics.draw( theme.iconEditOff, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	end
   elseif self.buttons[i] == 'save' then
   	love.graphics.draw( theme.iconSave, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'magic' then
   	love.graphics.draw( theme.iconMagic, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
   elseif self.buttons[i] == 'eye' then
	if self.class == "map" and atlas:isVisible(self) then
   		love.graphics.draw( theme.iconVisible, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	else
   		love.graphics.draw( theme.iconInvisible, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	end
   elseif self.buttons[i] == 'fog' then
	if maskType == 'RECT' then
   		love.graphics.draw( theme.iconSquare, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	else 
   		love.graphics.draw( theme.iconCircle, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	end
   elseif self.buttons[i] == 'scotch' and atlas:isVisible(self) then -- sticky icon only when map is visible
	if self.class == "map" and self.sticky then
   		love.graphics.draw( theme.iconSticky, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	else
   		love.graphics.draw( theme.iconUnSticky, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	end
   elseif self.buttons[i] == 'fullsize' then
	if self.fullSize then
   		love.graphics.draw( theme.iconReduce, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	else
   		love.graphics.draw( theme.iconFullSize, zxf - position * theme.iconSize + margin, zy - theme.iconSize + margin)
	end
   end -- if button

   end -- realx
   position=position-1
 end -- for

 -- max space for title
 local rzx = math.max(0,zx)
 local availableForTitle = 0
 if zx < 0 then
   availableForTitle = (self.w + zx) / self.mag - reservedForButtons 
 elseif zx + reservedForButtons > W then
   availableForTitle = 0
 else
   availableForTitle = self.w /self.mag - reservedForButtons 
 end
 if availableForTitle < 0 then availableForTitle = 0 end 
 local numChar = math.floor(availableForTitle / 8)
 local title = string.sub( self.title , 1, numChar ) 

 -- print title
love.graphics.setColor(0,0,0)
if self.class == "snapshot" then
 	love.graphics.print( title .. " (" .. #self.snapshots[self.currentSnap].s .. ")", rzx + 3 , zy - theme.iconSize + 3 )
 else
 	love.graphics.print( title , rzx + 3 , zy - theme.iconSize + 3 )
 end
 
 if self == self.layout:getFocus() then
  local x,y = love.mouse.getPosition()
  local button = self:isOverButton( x , y )
  if button and button == lastButton then
      if love.timer.getTime( ) - lastButtonTimer > lastButtonTimerDelay then
        love.graphics.setColor(color('white'))
	local zx = x
	if zx + 200 > W then zx = zx - 200 end	
	local h = 200
	if button == "fullsize" then h = 300 end
  	love.graphics.rectangle( "fill", zx, y, 200, h, 10, 10 )
  	love.graphics.setColor(color('black'))
  	love.graphics.setFont(theme.fontRound)
	local text = popupButtonText[button] or 'none'
  	love.graphics.printf( text , zx + 10, y + 10, 190 )
      end
  elseif not button then
        lastButton= nil
  else
        lastButton= button 
        lastButtonTimer = love.timer.getTime( )
  end
 end

end

function Window:drawResize()
   local W,H=self.layout.W, self.layout.H
   local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
   love.graphics.setColor(255,255,255)
   love.graphics.draw( theme.iconResize, zx + self.w / self.mag - theme.iconSize - 1, zy + self.h/self.mag - theme.iconSize - 1 )
end

function Window:drawBack()
  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  if self == self.layout:getFocus() then love.graphics.setColor(color('selected')) else love.graphics.setColor(color('grey')) end
  love.graphics.setLineWidth(border*2);
  love.graphics.rectangle( "line", zx, zy , ((self.w) / self.mag), (self.h / self.mag) )  
  love.graphics.setLineWidth(1);
  love.graphics.setColor(color('white'))
  love.graphics.rectangle( "fill", zx, zy, (self.w) / self.mag, (self.h) / self.mag )  
end

function Window:isOverButton(x,y)
	local W,H=self.layout.W, self.layout.H
 	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
 	local mx,my = self:WtoS(self.w, self.h) 
 	local tx, ty = mx - theme.iconSize, zy + 3
	tx, ty = math.min(tx,W-theme.iconSize), math.max(ty,0) + theme.iconSize

	local nButtons = #self.buttons
   	local zxf = math.min(zx + self.w / self.mag, W)
	local zyf = math.max(zy,theme.iconSize)

	if x >= zxf - nButtons * theme.iconSize and x <= zxf and y >= zyf - theme.iconSize and y <= zyf then
		-- click on a button . Which one ?
		local position = math.floor((x - (zxf - nButtons * theme.iconSize)) / theme.iconSize) + 1
		return self:getButtonByPosition(position)
	else
		return nil
	end
	end

-- click in the window. Check some rudimentary behaviour (quit...)
function Window:click(x,y)

		local W,H=self.layout.W, self.layout.H
 		local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
 		local mx,my = self:WtoS(self.w, self.h) 

		local p, index = nil, nil 
		if self.class == "map" then
		  p, index = self:isInsideIcons(x,y) 
		  if p then
			self:clickPawnAction(p,index)
		  end
		end

		local button = self:isOverButton(x,y)
		if button then

		if (button == 'close') then 	
			-- click on Close
			self.markForClosure = true
			-- mark the window for a future closure. We don't close it right now, because
			-- there might be another object clickable just below that would be wrongly
			-- activated ( a yui button ). So we wait for the mouse release to perform
			-- the actual closure
			return self
		elseif (button == 'always') then 	
			-- click on Always On Top 
			self.alwaysOnTop = not self.alwaysOnTop 
			self.layout:setOnTop(self, self.alwaysOnTop)
		elseif (button == 'unquad') then 	
			-- click on Always On Top 
			-- click on Expand (for maps with quad)
			-- remove the quad. restore to initial size
			self:setQuad()
		elseif (button == 'fullsize') then 	
			-- click on Maximize/Minimize at upper right corner 
			self:fullsize()	
		elseif (button == 'kill') then 	
			self:killAll()	
		elseif (button == 'wipe') then 	
			self:wipe()	
		elseif (button == 'next') then 	
			self:getNext()	
		elseif (button == 'round') then 	
			layout.combatWindow:nextRound()	
		elseif (button == 'hook') then 	
                    	layout.notificationWindow:addMessage( rpg.getHook() , 5 )
		elseif (button == 'partialT') then 	
                    	layout.notificationWindow:addMessage( rpg.getPartialT() , 8 )
		elseif (button == 'partialS') then 	
                    	layout.notificationWindow:addMessage( rpg.getPartialS() , 8 )
		elseif (button == 'magic') then 	
                    	layout.magicWindow:addMessage( rpg.getMagic() , 300 , 'darkblue' ) -- 5 minutes
		elseif (button == 'potion') then 	
                    	layout.magicWindow:addMessage( rpg.getPotion() , 120, 'darkblue' ) -- 2 minutes
		elseif (button == 'danger') then 	
                    	layout.notificationWindow:addMessage( rpg.getDanger() , 8 )
		elseif (button == 'name') then 	
                    	layout.notificationWindow:addMessage( rpg.getName() , 8 )
		elseif (button == 'edit') then 	
			self:toogleEditionMode()
		elseif (button == 'save') then 	
			self:saveText()
		elseif (button == 'fog') then 	
			if maskType == "RECT" then maskType = "CIRC" else maskType = "RECT" end
		elseif (button == 'eye') then 	
			local map = self
			atlas:toggleVisible( map )
                	if not atlas:isVisible( map ) then map.sticky = false else
                  		layout.notificationWindow:addMessage("Map '" .. map.displayFilename .. "' is now visible to players. All your changes will be relayed to them")
				if not map.mask or #map.mask <= 1 then
                    			layout.notificationWindow:addMessage("Map '" .. map.displayFilename .. "' is fully covered by Fog of War. Players will see nothing !")
                  		end
                	end
		elseif (button == 'scotch') then 	
			if self.sticky then 
				self:setUnsticky()	
			else
				self:setSticky()
			end
		end

		end -- button

	if x >= mx - theme.iconSize and y >= my - theme.iconSize then
		-- click on Resize at bottom right corner 
		if self.wResizable or self.hResizable or self.whResizable then mouseResize = true end
	elseif self.movable then
		-- clicking elsewhere, wants to move
		mouseMove = true
		arrowMode = false
		arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
	end

	return nil
	end

function Window:update(dt) 

	local W,H=self.layout.W, self.layout.H
	if self.markForSink then 
			self.markForSinkTimer = 0
			self.sinkSteps = self.sinkSteps + 1
		
			-- we translate the window
			Window.translate(self,self.markForSinkDeltax, self.markForSinkDeltay)
			-- where is the center on screen now ?
			local cx, cy = Window.WtoS(self,self.w/2,self.h/2)
			-- we want the scale to change, but keeping the window center unchanged
			self.mag = self.mag + self.markForSinkDeltaMag
			local tx,ty = Window.WtoS(self,self.w/2,self.h/2) -- if doing nothing, we would be there
			Window.translate(self,cx-tx, cy-ty) -- we apply the correct translation
		
			if self.sinkSteps >= sinkSteps then 
				self.markForSink = false -- finish sink movement
				self.layout.sinkInProgress = false 
				-- disappear eventually
				if not self.sinkFinalDisplay then 
					self.layout:setDisplay(self, false) 
					self.minimized = true
				else
					self.minimized = false
				end	
			end
	end
	end

function Window:drawWidgets() for i=1,#self.widgets do self.widgets[i]:draw() end end 

-- to be redefined in inherited classes
function Window:draw() for i=1,#self.widgets do self.widgets[i]:draw() end end 
function Window:getFocus() end
function Window:looseFocus() end
function Window:drop() end

return Window

