
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
		-- where are we within the window ?
		local H = self.h / self.mag
		if y <= zy + H / 3 then
			-- D20
			drawDicesKind = "d20" 
			launchDices("d20",1) 
		elseif y > zy + H/3 and y <= zy + 2 * H / 3 then
			-- D6 ATTACK
	  		if self.layout.combatWindow.focus then 
				drawDicesKind = "d6" 
				local n = rpg.rollAttack("attack") 
			end	
		else
			-- D6 DEFENSE
	  		if self.layout.combatWindow.focus then 
				drawDicesKind = "D6" 
				local n = rpg.rollAttack("armor") 
			end	
		end
	end

	end

return iconRollWindow

