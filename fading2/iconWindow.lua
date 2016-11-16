
local Window 	= require 'window'
local theme	= require 'theme'

local glowCode = [[
extern vec2 size;
extern int samples = 5; // pixels per axis; higher = bigger glow, worse performance
extern float quality = 2.5; // lower = smaller glow, better quality
 
vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc)
{
  vec4 source = Texel(tex, tc);
  vec4 sum = vec4(0);
  int diff = (samples - 1) / 2;
  vec2 sizeFactor = vec2(1) / size * quality;
  
  for (int x = -diff; x <= diff; x++)
  {
    for (int y = -diff; y <= diff; y++)
    {
      vec2 offset = vec2(x, y) * sizeFactor;
      sum += Texel(tex, tc + offset);
    }
  }
  
  return ((sum / (samples * samples)) + source) * colour;
} ]]


--
-- iconWindow class
-- a Icon is a window which displays a fixed image on the background . it is not zoomable, movable, no window bar
-- and always at bottom
--

local iconWindow = Window:new{ class = "icon", alwaysBottom = true, alwaysVisible = true, zoomable = false }

function iconWindow:new( t ) -- create from w, h, x, y + text, image,  mag
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.open = false 
  new.shader = love.graphics.newShader( glowCode ) 
  return new
end

function iconWindow:draw()
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  love.graphics.setColor(255,255,255)
  if self.open then
  	love.graphics.setShader(self.shader)
  	self.shader:send("size",{100,100})
  end
  love.graphics.draw( self.image, zx, zy , 0, 1/self.mag, 1/self.mag)
  if self.open then
  	love.graphics.setShader()
  end
  love.graphics.setFont(theme.fontTitle)
  local size = theme.fontTitle:getWidth(self.text)
  love.graphics.print( self.text, zx + (self.w/self.mag - size)/2, zy + 90  ) 
end

local function decideOpenWindow(window,cx,cy,w)
	if not window then return end
	if window.minimized then
		window:unsink(cx,cy,w,window.restoreSinkX, window.restoreSinkY, window.restoreSinkMag)
	elseif not window.layout:getDisplay(window) then
		window:unsink(cx,cy,w,window.startupX, window.startupY, window.startupMag)
	else
		window.layout:restoreBase(window)
	end 
	end

local function decideCloseWindow(window,cx,cy,w)
	if window.minimized or not window.layout:getDisplay(window) or window.alwaysVisible or 
		window.class == "dialog" or window.class == "help" or window.class == "setup" then
	  -- nothing to do 
	else
		window:sink(cx,cy,w)
	end
	end

function iconWindow:click(x,y)

  	local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
	if y < zy then 
		-- we click on (invisible) button bar. This moves the window as well
		mouseMove = true
		arrowMode = false
		arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
		return
	end

  	local cx,cy = Window.WtoS(self,self.w/2,self.h/2) 
	self.open = not self.open
	if self.open then -- only one opened at a time
	  if self == self.layout.storyWindow then
		self.layout.actionWindow.open = false
	  else
		self.layout.storyWindow.open = false
	  end
	end
	if self.text == "L'Action" then
		if self.open then
			decideOpenWindow(self.layout.combatWindow,cx,cy,0.3*self.w/self.mag)
	 		currentSnap = 2 -- tactical maps			
			self.layout.snapshotWindow:setTitle( snapText[currentSnap] )
			decideOpenWindow(self.layout.snapshotWindow,cx,cy,0.3*self.w/self.mag)
			decideOpenWindow(self.layout.pWindow,cx,cy,0.3*self.w/self.mag)
			-- sink all other windows
			for i=1,#self.layout.sorted do
				if self.layout.sorted[i].w.class == "map" and self.layout.sorted[i].w.kind == "map" and self.layout.sorted[i].w.minimized then
					decideOpenWindow(self.layout.sorted[i].w,cx,cy,0.3*self.w/self.mag)
				elseif self.layout.sorted[i].w ~= self.layout.combatWindow and 
				   self.layout.sorted[i].w ~= self.layout.pWindow and 
				   self.layout.sorted[i].w ~= self.layout.snapshotWindow and
				   self.layout.sorted[i].w.class ~= "dialog" and
				   self.layout.sorted[i].w.class ~= "setup" and
				   self.layout.sorted[i].w.class ~= "help" and
				   self.layout.sorted[i].d and 
				   not self.layout.sorted[i].w.alwaysVisible then

				  	self.layout.sorted[i].w:sink(cx,cy,0.3*self.w/self.mag)	

				end

			end
		else
			-- sink all windows
			for i=1,#self.layout.sorted do
				decideCloseWindow(self.layout.sorted[i].w,cx,cy,0.3*self.w/self.mag)
			end
		end
	elseif self.text == "L'Histoire" then
		if self.open then
	 		currentSnap = 1 -- images			
			self.layout.snapshotWindow:setTitle( snapText[currentSnap] )
			decideOpenWindow(self.layout.snapshotWindow,cx,cy,0.3*self.w/self.mag)
			decideOpenWindow(self.layout.pWindow,cx,cy,0.3*self.w/self.mag)
			decideOpenWindow(self.layout.scenarioWindow,cx,cy,0.3*self.w/self.mag)
			-- sink all other windows
			for i=1,#self.layout.sorted do
				if self.layout.sorted[i].w ~= self.layout.pWindow and 
				   self.layout.sorted[i].w ~= self.layout.snapshotWindow and
				   self.layout.sorted[i].w ~= self.layout.scenarioWindow and
				   self.layout.sorted[i].w.class ~= "dialog" and
				   self.layout.sorted[i].w.class ~= "setup" and
				   self.layout.sorted[i].w.class ~= "help" and
				   self.layout.sorted[i].d and 
				   not self.layout.sorted[i].w.alwaysVisible then

				  	self.layout.sorted[i].w:sink(cx,cy,0.3*self.w/self.mag)	

				end

			end
		else
			-- sink all windows
			for i=1,#self.layout.sorted do
				decideCloseWindow(self.layout.sorted[i].w,cx,cy,0.3*self.w/self.mag)
			end
		end
	end
end

return iconWindow

