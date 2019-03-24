
local theme = require 'theme'
local utf8  = require 'utf8'

local widget = {}

--
-- buttonWidget class
--
widget.buttonWidget = { x=0, y=0,	-- relative to the parent object
		 w=60, h=30,
	 	 parent = nil, text = "button",
		 onClick = nil,
  		 clickTimer = 0, clickTimerLimit = 0.05, clickDraw = false,
	       }

function widget.buttonWidget:new( t ) 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
  end

function widget.buttonWidget:click() 
	if self.onClick then self.onClick() end 
	self.clickDraw = true	
	end

function widget.buttonWidget:draw()
  local x,y = self.x, self.y
  local zx , zy = 0 , 0
  if self.parent then zx, zy = self.parent:WtoS(0,0) end
  if self.clickDraw then
    love.graphics.setColor(255,255,255,80)
    love.graphics.rectangle("fill",x+zx-10,y+zy-10,self.w+20,self.h+20)
  end
  love.graphics.setColor(theme.color.darkblue)
  love.graphics.rectangle("fill",x+zx,y+zy,self.w,self.h,3,3)
  love.graphics.setColor(theme.color.white)
  love.graphics.setFont( theme.fontSearch )
  local marginx = (self.w - theme.fontSearch:getWidth( self.text ))/2
  local marginy = (self.h - theme.fontSearch:getHeight())/2
  love.graphics.print(self.text,x+zx+marginx,y+zy+marginy)
  end

function widget.buttonWidget:update(dt) 
	if self.clickDraw then
	  self.clickTimer = self.clickTimer + dt
	  if self.clickTimer > self.clickTimerLimit then self.clickDraw = false; self.clickTimer = 0 end
	end
	end

function widget.buttonWidget:isInside(x,y)
  local lx,ly = self.x, self.y
  local zx , zy = 0 , 0
  if self.parent then zx, zy = self.parent:WtoS(0,0) end
  if x > lx + zx and x < lx + zx + self.w and 
	y > ly + zy and y < ly + zy + self.h then
	return true
  end 
  return false
  end

--
-- textWidget class
--
widget.textWidget = { 	x=0, y=0,	-- relative to the parent object
		w=200, h=20,
	 	parent = nil, selected = false,
		text = "" 
	     }

function widget.textWidget:new( t ) 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.bold 		= false
  new.fontSize 		= t.fontSize or DEFAULT_FONT_SIZE 
  new.fontHeight 	= math.floor(self:getFont(new.fontSize):getHeight())
  new.cursorTimer 	= 0
  new.flexible 		= false
  new.cursorTimerLimit 	= 0.355555
  new.cursorPosition 	= 0		-- index of the cursor (in the text)
  new.cursorPositionX 	= 0		-- x-position (at scale 1)
  new.cursorPositionY 	= 0		-- y-position (at scale 1)
  new.cursorDraw 	= false
  new.head 		= t.text or "" -- text is splitted in 2, so we can place cursor
  new.trail 		= ""
  new.textSelected 	= ""
  new.textSelectedPosition = 0
  new.textSelectedCursorLineOffset = 0
  new.cursorLineOffset 	= 0	-- vertical position of the cursor: 0 if we are on last line (the default), negative otherwise. It's a number of lines, not pixels
  new.lineOffset 	= 1	-- number of lines, used as an offset to display rectangle
  new.color 		= theme.color.black
  new.backgroundColor 	= theme.color.white
  return new
  end

-- count exact number of lines and set self.lineOffset properly, each time a new character is added
function widget.textWidget:setCorrectNumberOfLines()
		local t = self.head .. self.trail
		local remaining = t
		local len = string.len(t)
		self.lineOffset = 1		-- at minimum
		local currenty, currentx = 0, 0
		local mag = 1.0
		if self.parent then mag = self.parent.mag end
		local w = self.w / mag
		local i = 1
		while i <= len do
			local byteoffset = utf8.offset(remaining,2)
                	if byteoffset then
                        	c = string.sub(remaining,1,byteoffset-1)
				remaining = string.sub(remaining,1+byteoffset-1)
			else
				c = string.sub(remaining,i,i)
				remaining = string.sub(remaining,2)
                	end
			if c == "\n" then
				self.lineOffset = self.lineOffset + 1
				currentx = 0
			else
				if currentx + self:getFont():getWidth(c) > w then
					self.lineOffset = self.lineOffset + 1
					currentx = 0
				end
			end
			currentx = currentx + self:getFont():getWidth(c) 
			i = i + 1 
		end	
	end

-- recompute exact cursor positionX and Y when text is changed
-- this is done at scale 1, and result (X,Y) is at scale 1 also
--
function widget.textWidget:setCorrectCursorPosition(index)
		local index = index or 1
		local t = self.head .. self.trail
		local remaining = t
		local currenty, currentx = 0, 0
		local w = self.w 
		local i = 1
		local f = nil
		if self.bold then
			font = fontsBold
		else
			font = fonts
		end
		font = font[self.fontSize]
		while i <= index do
			local byteoffset = utf8.offset(remaining,2)
                	if byteoffset then
                        	c = string.sub(remaining,1,byteoffset-1)
				remaining = string.sub(remaining,1+byteoffset-1)
			else
				c = string.sub(remaining,i,i)
				remaining = string.sub(remaining,2)
                	end
			if c == "\n" then
				currentx = 0
				currenty = currenty + font:getHeight()
			else
				if currentx + font:getWidth(c) > w then
					currentx = 0
					currenty = currenty + font:getHeight() 
				end
			end
			currentx = currentx + font:getWidth(c) 
			i = i + 1 
		end	
		self.cursorPositionX, self.cursorPositionY = currentx , currenty 
	end

function widget.textWidget:select(y,x) 

	self.selected = true; 
	self.cursorTimer = 0

	if not y then
	
		-- DEFAULT, new empty widget 
		self.lineOffset = 1	
		self.cursorLineOffset = 0 
		self.cursorPosition = 0
		self.cursorPositionX = 0
		self.cursorPositionY = 0
		self.w = fonts[self.fontSize]:getWidth("X") -- set a default minimum width

	else
	
		local y = y or 0
		local x = x or 0
		local mag = 1.0
		if self.parent then mag = self.parent.mag end
		local w = self.w / mag
		x = x / mag
		y = y / mag

		-- We select a particular character 
		io.write("select called with " .. y .. " " .. x .. " " .. w .. "\n")	

		local t = self.head .. self.trail
		local remaining = t
		local len = string.len(t)
		self.head = ""
		self.trail = ""

		self.lineOffset = 1		-- at minimum
		self.cursorLineOffset = 0 
		local currenty, currentx = 0, 0
		local charFound = false
		local height = self:getFont():getHeight()

		local i = 1
		while i <= len do
			local byteoffset = utf8.offset(remaining,2)
                	if byteoffset then
                        	c = string.sub(remaining,1,byteoffset-1)
				remaining = string.sub(remaining,1+byteoffset-1)
			else
				c = string.sub(remaining,i,i)
				remaining = string.sub(remaining,2)
                	end
			if c == "\n" then
				if not charFound and y >= currenty and y < currenty + height then
					-- click zone is on this row, but within blank space. Take last character
					charFound = true; 
					self.cursorPosition = i - 1
					if self.cursorPosition < 0 then self.cursorPosition = 0 end
					self.cursorLineOffset = -(self.lineOffset - 1)  		-- minus 1 because offset starts at 0, not 1
				end
				self.lineOffset = self.lineOffset + 1
				currenty = currenty + height 
				currentx = 0
			else
				if currentx + self:getFont():getWidth(c) > w then
					self.lineOffset = self.lineOffset + 1
					currenty = currenty + height 
					currentx = 0
				end
			end
			if not charFound and currenty <= y and currenty + height > y and currentx <= x and currentx + self:getFont():getWidth(c) > x then 
				charFound = true; 
				self.head = self.head .. c
				self.cursorPosition = i 
				self.cursorLineOffset = -(self.lineOffset - 1) 	-- minus 1 because offset starts at 0, not 1
			elseif charFound then
				self.trail = self.trail .. c
			else 
				self.head = self.head .. c
			end
			currentx = currentx + self:getFont():getWidth(c) 
			i = i + 1 
		end	

		self:setCorrectCursorPosition(self.cursorPosition)

		io.write("=> head : '" .. self.head .. "'\n")
		io.write("=> trail : '" .. self.trail .. "'\n")
		io.write("=> cursorPosition : " .. self.cursorPosition .. "\n")
		io.write("=> cursorPositionX : " .. self.cursorPositionX .. "\n")
		io.write("=> cursorPositionY : " .. self.cursorPositionY .. "\n")

	end

	textActiveCallback = function(t) 
		self.head = self.head .. t 
		if t == "\n" then
			self.lineOffset = self.lineOffset + 1
			self.cursorLineOffset = self.cursorLineOffset - 1
			self.flexible = false
		end 
		self.cursorPosition = self.cursorPosition + 1
		if self.flexible then self.w = self.w + fonts[self.fontSize]:getWidth(t) end
		self:setCorrectCursorPosition(self.cursorPosition)
		self:setCorrectNumberOfLines()
		end 

	textActiveBackspaceCallback = function()  
		if self.head ~= "" then 
			local remove = ""
         	  	local byteoffset = utf8.offset(self.head, -1)
         		if byteoffset then 
				remove = string.sub(self.head,byteoffset)
				self.head = string.sub(self.head, 1, byteoffset - 1) 
			end 
			if remove == "\n" then
				self.lineOffset = self.lineOffset - 1
				self.lineOffset = math.max(0,self.lineOffset)
				self.cursorLineOffset = self.cursorLineOffset + 1
			end
			self.cursorPosition = self.cursorPosition - 1
			if self.cursorPosition < 0 then self.cursorPosition = 0 end
			if self.flexible then self.w = self.w - fonts[self.fontSize]:getWidth(remove) end
			self:setCorrectCursorPosition(self.cursorPosition)
			self:setCorrectNumberOfLines()
		end
		end

	textActiveCopyCallback = function() 
		love.system.setClipboardText(self.textSelected)
		self.textSelected = ""; self.textSelectedPosition = 0; self.textSelectedCursorLineOffset = 0
		end

	textActivePasteCallback = function() 
		local t = love.system.getClipboardText( )
		self.head = self.head .. t
		self.cursorPosition = self.cursorPosition + string.len(t) 
		self:setCorrectCursorPosition(self.cursorPosition)
		self:setCorrectNumberOfLines()
		end 

	textActiveLeftCallback = function() 
		if self.head == "" then return end
         	local byteoffset = utf8.offset(self.head, -1)
		local remove = ""
         	if byteoffset then 
			remove = string.sub(self.head,byteoffset)
			self.head = string.sub(self.head, 1, byteoffset - 1) 
		end 
		if remove == "\n" then
			self.cursorLineOffset = self.cursorLineOffset + 1
		end
		self.trail = remove .. self.trail
		if love.keyboard.isDown("lshift") then
			if self.textSelected == "" then self.textSelectedPosition = self.cursorPosition ; self.textSelectedCursorLineOffset = self.cursorLineOffset end
			self.textSelected = remove .. self.textSelected
		else
			self.textSelected = "" ; self.textSelectedPosition = 0 ; self.textSelectedCursorLineOffset = 0
		end
		self.cursorPosition = self.cursorPosition - 1
		if self.cursorPosition < 0 then self.cursorPosition = 0 end
		self:setCorrectCursorPosition(self.cursorPosition)
		end 

	textActiveUpCallback = function() 
		if self.cursorLineOffset == 0 then return end
		io.write("cursor is at " .. self.cursorPositionY .. ", now calling at " .. self.cursorPositionY - fonts[self.fontSize]:getHeight() / 2 .. "\n")
		self:select( self.cursorPositionY - fonts[self.fontSize]:getHeight() / 2, self.cursorPositionX )
		end 

	textActiveDownCallback = function() 
		io.write("cursor is at " .. self.cursorPositionY .. ", now calling at " .. self.cursorPositionY + fonts[self.fontSize]:getHeight() / 2 .. "\n")
		self:select( self.cursorPositionY + fonts[self.fontSize]:getHeight() * 1.5 , self.cursorPositionX )
		end 


	textActiveRightCallback = function() 
		if self.trail == "" then return end
         	local byteoffset = utf8.offset(self.trail,2) 
		local remove = ""
         	if byteoffset then 
			remove = string.sub(self.trail,1,byteoffset-1)
			self.trail = string.sub(self.trail, byteoffset) 
		end 
		if remove == "\n" then
			self.cursorLineOffset = self.cursorLineOffset - 1
		end
		self.head = self.head .. remove 
		if love.keyboard.isDown("lshift") then
			if self.textSelected == "" then self.textSelectedPosition = self.cursorPosition ; self.textSelectedCursorLineOffset = self.cursorLineOffset end
			self.textSelected = self.textSelected .. remove
		else
			self.textSelected = "" ; self.textSelectedPosition = 0 ; self.textSelectedCursorLineOffset = 0
		end
		self.cursorPosition = self.cursorPosition + 1
		self:setCorrectCursorPosition(self.cursorPosition)
		end 

	end

function widget.textWidget:unselect() 
	if self.selected then 
		self.cursorLineOffset = 0
		self.selected = false
		self.flexible = false
		textActiveCallback = nil 
		textActiveBackspaceCallback = nil 
		textActivePasteCallback = nil 
		textActiveCopyCallback = nil 
		textActiveLeftCallback = nil 
		textActiveRightCallback = nil 
	end 
	end

function widget.textWidget:lastLine()
  -- get the last carriage return, or the beginning of head
  local rewind = "" 
  local i = string.len(self.head)
  while i > 1 do
  	rewind = string.sub(self.head,i,i)
	if rewind == "\n" then break end
	i = i - 1
  end
  return string.sub(self.head,i,string.len(self.head))
  end

function widget.textWidget:setCursorPosition()
  local s = self:lastLine()
  self.cursorPosition = self:getFont():getWidth( s ) 
  end

function widget.textWidget:getText() return self.head .. self.trail end

function widget.textWidget:click() self:select() end

function widget.textWidget:draw()
  local x,y = self.x, self.y
  local zx , zy = 0 , 0
  if self.parent then zx, zy = self.parent:WtoS(0,0) end
  local mag = 1.0
  if self.parent then mag = self.parent.mag end
  local fh = self:getFont():getHeight()
  if self.selected then
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line",x/mag+zx-2,y/mag+zy-2,self.w/mag+4,self.lineOffset*fh+4)
    love.graphics.setColor(unpack(self.backgroundColor))
    love.graphics.rectangle("fill",x/mag+zx-2,y/mag+zy-2,self.w/mag+4,self.lineOffset*fh+4)
    love.graphics.setColor(0,0,0)
  end
  love.graphics.setColor(unpack(self.color))
  local f = self:getFont()
  	love.graphics.setFont( f )
	local t = self.head .. self.trail
	local remaining = t
	local len = string.len(t)
	local currenty, currentx = 0, 0
	local height = f:getHeight()

	-- special case where cursor is at start
    	if 0 == self.cursorPosition and self.cursorDraw then 
			love.graphics.line(zx+self.x/mag, 
					   zy+self.y/mag, 
					   zx+self.x/mag, 
					   zy+self.y/mag + height) 
    	end

	local i = 1
	while i <= len do
		local byteoffset = utf8.offset(remaining,2)
               	if byteoffset then
                       	c = string.sub(remaining,1,byteoffset-1)
			remaining = string.sub(remaining,1+byteoffset-1)
		else
			c = string.sub(remaining,i,i)
			remaining = string.sub(remaining,2)
               	end
		if c == '\n' then
			currenty = currenty + height
			currentx = 0
		else
			if currentx + f:getWidth(c) > self.w / mag then
				currentx = 0
				currenty = currenty + height
  				love.graphics.print(c,math.floor(currentx+zx+self.x/mag),math.floor(currenty+zy+self.y/mag))
				currentx = currentx + f:getWidth(c)
			else
  				love.graphics.print(c,math.floor(currentx+zx+self.x/mag),math.floor(currenty+zy+self.y/mag))
				currentx = currentx + f:getWidth(c)
			end
		end
    		if i == self.cursorPosition and self.cursorDraw then 
			love.graphics.line(currentx+zx+self.x/mag, 
					   currenty+zy+self.y/mag, 
					   currentx+zx+self.x/mag, 
					   currenty+zy+self.y/mag + height) 
    		end
		i = i + 1
	end
    
  if self.textSelected ~= "" then
    love.graphics.setColor(theme.color.red)
    love.graphics.line(		self.textSelectedPosition + x/mag + zx , 
				y/mag+zy-self.textSelectedCursorLineOffset*fh, 
				self.textSelectedPosition + x/mag + zx , 
				y/mag+zy+self.h-self.textSelectedCursorLineOffset*fh
			  ) 
  end
  --love.graphics.setScissor()
  end

function widget.textWidget:update(dt)
  if self.selected then 
    self.cursorTimer = self.cursorTimer + dt
    if self.cursorTimer > self.cursorTimerLimit then self.cursorDraw = not self.cursorDraw ; self.cursorTimer = 0 end
  end 
  end

function widget.textWidget:isInside(x,y)
  local lx,ly = self.x, self.y
  local zx , zy = 0 , 0
  if self.parent then zx, zy = self.parent:WtoS(0,0) end
  if x > lx + zx and x < lx + zx + self.w and 
	y > ly + zy and y < ly + zy + self.h then
	return true
  end 
  return false
  end

function widget.textWidget:getFont(i)
  i = i or self.fontSize 
  local mag = 1.0
  if self.parent then mag = self.parent.mag end
  local fontSize = math.floor(((i or DEFAULT_FONT_SIZE ) / mag)+0.5)
  if fontSize >= MIN_FONT_SIZE and fontSize <= MAX_FONT_SIZE then
    if self.bold then
  	return fontsBold[fontSize]
    else
	return fonts[fontSize]
    end
  end
  end

function widget.textWidget:incFont()
  if self.fontSize < MAX_FONT_SIZE then 
	self.fontSize = self.fontSize + 1 
	self.fontHeight = self:getFont():getHeight()
	self:setCorrectNumberOfLines()
  end
  end

function widget.textWidget:decFont()
  if self.fontSize > MIN_FONT_SIZE then 
	self.fontSize = self.fontSize - 1 
	self.fontHeight = self:getFont():getHeight()
	self:setCorrectNumberOfLines()
  end
  end

function widget.textWidget:toggleBold()
  self.bold = not self.bold
  self:setCorrectNumberOfLines()
  end

return widget

