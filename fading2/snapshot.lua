
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme

-- snapshots
local snapshots    = {}
snapshots[1] = { s = {}, index = 1, offset = 0 }        -- small snapshots at the bottom, for general images
snapshots[2] = { s = {}, index = 1, offset = 0 }        -- small snapshots at the bottom, for scenario & maps
snapshots[3] = { s = {}, index = 1, offset = 0 }        -- small snapshots at the bottom, for PNJ classes 
snapshots[4] = { s = {}, index = 1, offset = 0 }        -- small snapshots at the bottom, for windows -- not used so far, reserved
local snapText = { "PICTURES", "MAPS", "CHARACTERS", "WINDOWS" }

local iconSize = theme.iconSize

--
-- snapshotBarclass
-- a snapshotBar is a window which displays images
--

local snapshotBar = Window:new{ class = "snapshot" , title = snapText[1] , wResizable = true , hResizable = true, 
				download = true , buttons = { 'next', 'always', 'close' } }

function snapshotBar:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.snapshots = snapshots
  new.snapText = snapText
  new.currentSnap = 1 
  new.lines = 1
  new.maxPerLine = #snapshots[1].s
  return new
end

function snapshotBar:download()
	-- deprecated
	end

function snapshotBar:draw()

  self:drawBack(mainAlpha)

  love.graphics.setColor(255,255,255)

  local snapshotSize = self.layout.snapshotSize
  local snapshotMargin = self.layout.snapshotMargin
  local zx,zy = -( self.x * 1/self.mag - self.layout.W / 2), -( self.y * 1/self.mag - self.layout.H / 2)
  --local basex = zx + snapshots[self.currentSnap].offset
  for line = 1, self.lines do 

    for i=1 + self.maxPerLine * (line - 1), (self.maxPerLine * line) do
	if i > #snapshots[self.currentSnap].s then break end
    	local relativeIndex = i - self.maxPerLine * (line - 1)
	local x = zx + snapshots[self.currentSnap].offset + (snapshotSize + snapshotMargin) * (relativeIndex-1) - (snapshots[self.currentSnap].s[i].w * snapshots[self.currentSnap].s[i].snapmag - snapshotSize) / 2
	if x > zx + self.w / self.mag  + snapshotSize then break end
	if x >= zx - snapshotSize then 
  		love.graphics.setScissor( zx, zy, self.w / self.mag, self.h / self.mag ) 
		if snapshots[self.currentSnap].s[i].selected then
  			love.graphics.setColor(unpack(theme.color.red))
			love.graphics.rectangle("fill", 
				zx + snapshots[self.currentSnap].offset + (snapshotSize + snapshotMargin) * (relativeIndex-1),
				zy + 5 + (line-1)*(snapshotSize + snapshotMargin), 
				snapshotSize, 
				snapshotSize)
		elseif snapshots[self.currentSnap].s[i].highlight then
  			love.graphics.setColor(unpack(theme.color.darkblue))
			love.graphics.rectangle("fill", 
				zx + snapshots[self.currentSnap].offset + (snapshotSize + snapshotMargin) * (relativeIndex-1),
				zy + 5 + (line-1)*(snapshotSize + snapshotMargin), 
				snapshotSize, 
				snapshotSize)
		end
		if self.currentSnap == 2 and snapshots[self.currentSnap].s[i].kind == "scenario" then
			-- do not draw scenario, ... 
			-- deprecated
		else
  			if self.currentSnap == 2 and layout:openedOnce(snapshots[self.currentSnap].s[i]) then
				-- draw in different color if it's a map and it was opened at least once
				love.graphics.setColor(theme.color.orange)
			else
				love.graphics.setColor(255,255,255)
			end
			love.graphics.draw( 	snapshots[self.currentSnap].s[i].thumb , x , zy + (line-1)*(snapshotSize + snapshotMargin) - ( snapshots[self.currentSnap].s[i].h * snapshots[self.currentSnap].s[i].snapmag - snapshotSize ) / 2 + 2 )

		end
  		love.graphics.setScissor() 
	end
   end

  end
 
   -- print bar
   self:drawBar()

   -- print over text eventually
   if layout:getFocus() == self then
 
     love.graphics.setFont(theme.fontRound)
     local x,y = love.mouse.getPosition()
     local left = math.max(zx,0)
     local right = math.min(zx+self.w,self.layout.W)
	
     if x > left and x < right and y > zy and y < zy + self.h and
	not ( x > right - 24 and y > zy + self.h - 24 ) -- escape if we are over resize icon	
	then
	-- display text is over a class image
	local line = math.floor((y - zy) / (snapshotSize + snapshotMargin)) + 1
    	local index = (line - 1) * self.maxPerLine + math.floor(((x-zx) - snapshots[self.currentSnap].offset) / ( snapshotSize + snapshotMargin)) + 1
    	if index >= 1 and index <= #snapshots[self.currentSnap].s then
		if self.currentSnap == 3 then
			local size = theme.fontRound:getWidth( RpgClasses[index].class )
			local px = x + 5
			if px + size > self.layout.W then px = px - size end
   			love.graphics.setColor(255,255,255)
			love.graphics.rectangle("fill",px,y-20,size,theme.fontRound:getHeight())
   			love.graphics.setColor(0,0,0)
			love.graphics.print( RpgClasses[index].class , px, y-20 )
		else
			if snapshots[self.currentSnap].s[index].displayFilename then
			  local size = theme.fontRound:getWidth( snapshots[self.currentSnap].s[index].displayFilename )
			  local px = x + 5
			  if px + size > self.layout.W then px = px - size end
   			  love.graphics.setColor(255,255,255)
			  love.graphics.rectangle("fill",px,y-20,size,theme.fontRound:getHeight())
   			  love.graphics.setColor(0,0,0)
			  love.graphics.print( snapshots[self.currentSnap].s[index].displayFilename, px, y-20 )
			end
		end
	end
     end
 
   end

   self:drawResize()

end

function snapshotBar:update(dt)
	
  	local snapshotSize = self.layout.snapshotSize
  	local snapshotMargin = self.layout.snapshotMargin

	Window.update(self,dt)

	self.lines = math.ceil(self.h / (layout.snapshotSize + layout.snapshotMargin))
	if self.lines == 0 then self.lines = 1 end
	self.maxPerLine = math.ceil(#snapshots[self.currentSnap].s / self.lines)

  	local zx,zy = -( self.x - self.layout.W / 2), -( self.y - self.layout.H / 2)

   	if layout:getFocus() == self then

	  -- change snapshot offset if mouse  at bottom right or left
	  --local snapMax = #snapshots[self.currentSnap].s * (snapshotSize + snapshotMargin) - self.w
	  local snapMax = self.maxPerLine * (snapshotSize + snapshotMargin) - self.w
	  if snapMax < 0 then snapMax = 0 end
	  local x,y = love.mouse.getPosition()
	  local left = math.max(zx,0)
	  local right = math.min(zx+self.w,self.layout.W)
	
	  if x > left and x < right then

	    if (x < left + snapshotMargin * 4 ) and (y > zy) and (y < zy + self.h) then
	  	snapshots[self.currentSnap].offset = snapshots[self.currentSnap].offset + snapshotMargin * 2
	  	if snapshots[self.currentSnap].offset > 0 then snapshots[self.currentSnap].offset = 0  end
	    end

	    if (x > right - snapshotMargin * 4 ) and (y > zy) and (y < zy + self.h - iconSize) then
	  	snapshots[self.currentSnap].offset = snapshots[self.currentSnap].offset - snapshotMargin * 2
	  	if snapshots[self.currentSnap].offset < -snapMax then snapshots[self.currentSnap].offset = -snapMax end
	    end

	  end

	end

	end


function snapshotBar:click(x,y)

  local zx,zy = -( self.x - self.layout.W / 2), -( self.y - self.layout.H / 2)
  local snapshotSize = self.layout.snapshotSize
  local snapshotMargin = self.layout.snapshotMargin
  
  Window.click(self,x,y)

  if (y < zy) or (zy < iconSize and y < iconSize) then return end -- clicking on the button bar should not select an image... 
 
  if x > zx + self.w - 24 and y > zy + self.h - 24 then return end -- being over Resize icon should not neither...
 
  mouseMove = false -- Window.click() above might set mouseMove improperly. We force it now
 
    --arrowMode = false
    -- check if there is a snapshot there
    local line = math.floor((y - zy) / (snapshotSize + snapshotMargin)) + 1
    local index = (line - 1) * self.maxPerLine + math.floor(((x-zx) - snapshots[self.currentSnap].offset) / ( snapshotSize + snapshotMargin)) + 1
    -- 2 possibilities: if this image is already selected, then use it
    -- otherwise, just select it (and deselect any other eventually)
    if index >= 1 and index <= #snapshots[self.currentSnap].s then

      -- this may start a drag&drop
      dragMove = true
      dragObject = { originWindow = self, snapshot = snapshots[self.currentSnap].s[index] }
      if self.currentSnap == 1 then dragObject.object = { class = "image" } end
      if self.currentSnap == 2 then dragObject.object = { class = "map" , map = snapshots[self.currentSnap].s[index] } end
      if self.currentSnap == 3 then dragObject.object = { class = "pnj", rpgClass = RpgClasses[index] } end
      --if self.currentSnap == 4 then dragObject.object = { class = "pawn" } end

      if snapshots[self.currentSnap].s[index].selected then
	      -- already selected
	      snapshots[self.currentSnap].s[index].selected = false 

	      -- Three different ways to use a snapshot

	      -- 1: general image, sent it to projector
	      if self.currentSnap == 1 then
	      	layout.pWindow.currentImage = snapshots[self.currentSnap].s[index].im
	      	layout.pWindow.o = nil
	      	-- remove the 'visible' flag from maps (eventually)
	      	atlas:removeVisible()
		tcpsend(projector,"ERAS") 	-- remove all pawns (if any) 
    	      	-- send the filename over the socket
		if snapshots[self.currentSnap].s[index].is_local then
			tcpsendBinary{ file = snapshots[self.currentSnap].s[index].file } 
 			tcpsend(projector,"BEOF")
		elseif fullBinary then
			tcpsendBinary{ filename = snapshots[self.currentSnap].s[index].filename } 
 			tcpsend(projector,"BEOF")
		else
	      		tcpsend( projector, "OPEN " .. snapshots[self.currentSnap].s[index].baseFilename)
		end
	      	tcpsend( projector, "DISP") 	-- display immediately

	      -- 2: map. This should open a window 
	      elseif self.currentSnap == 2 then

			self.layout:setDisplay( snapshots[self.currentSnap].s[index] , true )
			self.layout:setFocus( snapshots[self.currentSnap].s[index] ) 
	
	      -- 3: Pawn. If focus is set, use this image as PJ/PNJ pawn image 
	      elseif self.currentSnap == 3 then
			
			-- do nothing

	      else
			io.write("internal error. should not come here")

	      end

      else
	      -- not selected, select it now
	    for i,v in ipairs(snapshots[self.currentSnap].s) do
	      if i == index then snapshots[self.currentSnap].s[i].selected = true
	      else snapshots[self.currentSnap].s[i].selected = false end
	    end

	    -- If in pawn mode, this does NOT change the focus, so we break now !
	    if self.currentSnap == 3 then return end
      end
  end

  end

function snapshotBar:getNext()
  self.currentSnap = self.currentSnap + 1
  if self.currentSnap == 4 then self.currentSnap = 1 end -- we ignore snapshots[4], not used for the moment
  self:setTitle( self.snapText[self.currentSnap] )
  end

function snapshotBar:resize()
  local s = layout.snapshotSize + layout.snapshotMargin

  local num = math.floor(#self.snapshots[self.currentSnap].s / self.lines)
  --local num = math.floor( self.w / s )
  if num < 2 then num = 2 end
  self.w = num * s
  if self.w > layout.W then self.w = layout.W end

  self.lines = math.ceil(self.h / s)
  --self.lines = math.floor(#self.snapshots[self.currentSnap].s * s / self.w )
  if self.lines == 0 then self.lines = 1 end
  self.h = self.lines * s
  for i=1,4 do self.snapshots[i].offset = 0 end

  end

-- apply a function f to all maps
function snapshotBar:apply( f )

  for i,v in ipairs(snapshots[2].s) do
	f( v )
  end

  end

return snapshotBar

