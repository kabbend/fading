
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	-- widgets components

--
-- setupWindow class
--
local setupWindow = Window:new{ class = "setup" }

function setupWindow:new( t ) -- create from w, h, x, y, init
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  if t.init then new.title = "CONFIGURATION DATA" else new.title = "PLEASE PROVIDE MANDATORY INFORMATION" end
  new.text1 = widget.textWidget:new{ x = 150, y = 25 , w = 440, text = baseDirectory }
  new.text2 = widget.textWidget:new{ x = 150, y = 55, w = 440, text = fadingDirectory }
  new.text3 = widget.textWidget:new{ x = 150, y = 85, w = 150, text = serverport }
  if t.init then 
	new.save  = widget.buttonWidget:new{ x = 440, y = new.h - 45, text = "Save", onClick = function() new:setupSave() end }
  	new:addWidget(new.save)
  	new.load  = widget.buttonWidget:new{ x = 515, y = new.h - 45, text = "Restart", w=70,onClick = function() new:setupLoad() end }
  else
  	new.load  = widget.buttonWidget:new{ x = 510, y = new.h - 45, text = "Start", onClick = function() new:setupLoad() end }
  end
  new:addWidget(new.text1)
  new:addWidget(new.text2)
  new:addWidget(new.text3)
  new:addWidget(new.load)
  return new
end

function setupWindow:setupSave()
  local t1 = self.text1:getText() or ""
  local t2 = self.text2:getText() or ""
  local t3 = self.text3:getText() or ""
  local file, msg, code = io.open("fading2/fsconf.lua",'w')
  if not file then io.write("cannot write to conf file: " .. tostring(msg) .. "\n") ; return end
  file:write( "-- fading suns conf file\n")
  file:write( "baseDirectory = '" .. t1 .. "'\n")
  file:write( "fadingDirectory = '" .. t2 .. "'\n")
  file:write( "serverport = " .. t3 .. "\n")
  file:close()
  end

function setupWindow:setupLoad()
  self:setupSave()
  dofile("fading2/fsconf.lua")
  self.layout:setDisplay(self,false)  
  self.markForClosure = true
  love.event.quit("restart")
  end

function setupWindow:draw()
  local W,H=self.layout.W, self.layout.H
  self:drawBack()
  self:drawWidgets()
  love.graphics.setFont(theme.fontRound)
  love.graphics.setColor( theme.color.black )
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  love.graphics.print("BASE DIRECTORY *", zx + 5, zy + 25 )
  love.graphics.print("SCENARIO", zx + 5, zy + 55 )
  love.graphics.print("SERVER IP PORT *", zx + 5, zy + 85 )
  self:drawBar()
  end

function setupWindow:click(x,y)
  if self.init then Window.click(self,x,y) end
  if self.text1:isInside(x,y) then self.text1:select() else self.text1:unselect() end 
  if self.text2:isInside(x,y) then self.text2:select() else self.text2:unselect() end 
  if self.text3:isInside(x,y) then self.text3:select() else self.text3:unselect() end 
  if self.load:isInside(x,y) then self.load:click() end 
  if self.save then if self.save:isInside(x,y) then self.save:click() end end
  end

function setupWindow:update(dt)
  for i=1,#self.widgets do self.widgets[i]:update(dt) end
  end

return setupWindow

