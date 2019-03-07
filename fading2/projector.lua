
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme

-- projectorWindow class
-- a projectorWindow is a window which displays images. it is not zoomable
local projectorWindow = Window:new{ class = "projector" , title = "DISPLAY", buttons = { 'always', 'close'}  }

function projectorWindow:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  self.currentImage = nil
  self.dice = nil
  return new
end

function projectorWindow:drawDicesResult(d)
  self.dice = d;
end

function projectorWindow:draw()

  self:drawBack(mainAlpha)

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x - W / 2), -( self.y - H / 2)
  if self.currentImage and not self.dice then 
    local w, h = self.currentImage:getDimensions()
    -- compute magnifying factor f to fit to screen, with max = 2
    local xfactor = (self.layout.W1) / w
    local yfactor = (self.layout.H1) / h
    local f = math.min( xfactor, yfactor )
    if f > 2 then f = 2 end
    w , h = f * w , f * h
    love.graphics.draw( self.currentImage , zx +  (self.layout.W1 - w) / 2, zy + ( self.layout.H1 - h ) / 2, 0 , f, f )
  end

  -- print dice result eventually
  if self.dice then
      love.graphics.setColor(unpack(theme.color.white))
      love.graphics.rectangle("fill",zx, zy, self.layout.W1 , self.layout.H1 );
      love.graphics.setColor(unpack(theme.color.black))
      love.graphics.setFont(theme.fontDice)
      local w = theme.fontDice:getWidth( self.dice );
      local h = theme.fontDice:getHeight( self.dice );
      love.graphics.print(self.dice, zx +  (self.layout.W1 - w) / 2, zy + ( self.layout.H1 - h ) / 2 - 15);
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
	end

	end

return projectorWindow

