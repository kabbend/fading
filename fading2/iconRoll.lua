
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local rpg		= require 'rpg'	

--
-- iconRollWindow class
-- 
iconRollWindow = Window:new{ class = "roll", alwaysOnTop = true, alwaysVisible = true, zoomable = false, closable = false }

function iconRollWindow:new( t ) -- create from w, h, x, y, image, mag
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function iconRollWindow:draw()
  	local W,H=self.layout.W, self.layout.H
  	local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  	love.graphics.setColor(255, 255, 255, 255);
  	love.graphics.draw( self.image, zx, zy , 0, 1/self.mag, 1/self.mag)
	end

function iconRollWindow:click(x,y)

  	local W,H=self.layout.W, self.layout.H
  	local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
	if y < zy then 
		-- we click on (invisible) button bar. This moves the window as well
		mouseMove = true
		arrowMode = false
		arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
	else 
	  	if self.layout.combatWindow.focus then 
			drawDicesKind = "d6" 
			local n = rpg.rollAttack("attack") 
			if n == 0 then -- no attack to roll, so we roll a d20 instead...
				drawDicesKind = "d20" 
				launchDices("d20",1) 
			end	
		else 
			drawDicesKind = "d20" 
			launchDices("d20",1) 
		end	
	end

	end

return iconRollWindow

