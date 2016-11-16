
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme

-- projectorWindow class
-- a projectorWindow is a window which displays images. it is not zoomable
local projectorWindow = Window:new{ class = "projector" , title = "PROJECTOR" }

function projectorWindow:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  self.currentImage = nil
  return new
end

function projectorWindow:draw()

  self:drawBack()

  local zx,zy = -( self.x - W / 2), -( self.y - H / 2)
  if self.currentImage then 
    local w, h = self.currentImage:getDimensions()
    -- compute magnifying factor f to fit to screen, with max = 2
    local xfactor = (self.layout.W1) / w
    local yfactor = (self.layout.H1) / h
    local f = math.min( xfactor, yfactor )
    if f > 2 then f = 2 end
    w , h = f * w , f * h
    love.graphics.draw( self.currentImage , zx +  (self.layout.W1 - w) / 2, zy + ( self.layout.H1 - h ) / 2, 0 , f, f )
  end
  -- print bar
  self:drawBar()
  end

function projectorWindow:click(x,y)
  	Window.click(self,x,y)
	end

function projectorWindow:drop(o)
	self.currentImage = o.snapshot.im	
	end

return projectorWindow

