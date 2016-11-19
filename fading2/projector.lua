
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

  local W,H=self.layout.W, self.layout.H
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

 	local s = o.snapshot

	-- replace the image locally
	self.currentImage = s.im	

	-- and send it remotely
	if  o.object.class == "pnjtable" or o.object.class == "image" or o.object.class == "pnj" or  o.object.class == "pawn" then
		-- image coming from the combat window (pnjtable) or from the snapshot bar
                -- remove the 'visible' flag from maps (eventually)
                atlas:removeVisible()
                tcpsend(projector,"ERAS")       -- remove all pawns (if any) 
                -- send the filename over the socket
                if s.is_local then
                        tcpsendBinary{ file = s.file }
                        tcpsend(projector,"BEOF")
                elseif fullBinary then
                        tcpsendBinary{ filename = s.filename }
                        tcpsend(projector,"BEOF")
                else
                        tcpsend( projector, "OPEN " .. s.baseFilename)
                end
                tcpsend( projector, "DISP")     -- display immediately

	elseif o.object.class == "map" then
		-- map coming from the snapshot bar. This is equivalent to open it and make it visible
		-- open the window map, put focus
                s.layout:setDisplay( s , true )
                s.layout:setFocus( s )
		-- make it visible
		atlas:toggleVisible( s )
                if not atlas:isVisible( s ) then s.sticky = false end
	end

	end

return projectorWindow

