
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
  		 clickTimer = 0, clickTimerLimit = 0.3, clickDraw = false,
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
  new.bold = false
  new.fontSize = t.fontSize or DEFAULT_FONT_SIZE 
  new.fontHeight = math.floor(self:getFont(new.fontSize):getHeight())
  new.cursorTimer = 0
  new.cursorTimerLimit = 0.5
  new.cursorPosition = 0
  new.cursorDraw = false
  -- text is splitted in 2, so we can place cursor
  new.head = t.text or ""
  new.trail = ""
  new.textSelected = ""
  new.textSelectedPosition = 0
  new.textSelectedCursorLineOffset = 0
  new.xOffset = 0		-- if the line is too long, we shift print on the left (negative offset) so we always sees the end
  new.cursorLineOffset = 0	-- vertical position of the cursor: 0 if we are on last line (the default), negative otherwise. It's a number of lines, not pixels
  new.lineOffset = 0		-- number of lines, used as an offset to display rectangle
  new.color = theme.color.black
  new.backgroundColor = theme.color.white
  new:setCursorPosition() 
  return new
  end

function widget.textWidget:select(y,x,w) 

	self.selected = true; 
	self.cursorTimer = 0

	-- retrieve lineOffset based on number of lines
	local s = self.head .. self.trail
	for i=1,string.len(s) do
		if string.sub(s,i,i) == '\n' then self.lineOffset = self.lineOffset + 1 end
	end

	-- determine minimum height depending on font size
	self:updateBaseHeight()

	if not y then
	
		-- DEFAULT, we select the last line

		-- in this version we always select the end of the text
		-- hence no cursor line offset (last line), xOffset based on last line length
		self.cursorLineOffset = 0

		-- retrieve text xOffset based on last line 
		local ll = self:lastLine()
		local llsize = self:getFont():getWidth(ll)
		if llsize > self.w then
			self.xOffset = self.w - llsize -- negative offset  
		else
			self.xOffset = 0
		end


	else
	
		-- We select a particular line
		-- y is the y-coordinate in the widget at scale 1, w the width (at scale 1) of the text zone we just selected
	
		io.write("select called with " .. y .. " " .. x .. " " .. w .. "\n")	

		local t = self.head .. self.trail
		self.head = ""
		self.trail = ""
		local line, currenty, currentx = 1, 0, 0
		local i = 1
		local len = string.len(t)
		local remaining = t
		local justFound, found = false, false
		local result = nil
		local height = self:getFont():getHeight()
		local currentLine, resultLine = "", nil 
		while i <= len do
			if currenty <= y and currenty + height > y and currentx <= x and currentx + self.fontSize > x then 
				justFound = true; found = true; result = line end -- we continue until end of this line, to get its length 
			local byteoffset = utf8.offset(remaining,2)
                	if byteoffset then
                        	c = string.sub(remaining,1,byteoffset-1)
				remaining = string.sub(remaining,1+byteoffset-1)
			else
				c = string.sub(remaining,i,i)
				remaining = string.sub(remaining,2)
                	end
			if c == "\n" then
				line = line + 1
				currentLine = ""
				currenty = currenty + height 
				currentx = 0
			else
				currentLine = currentLine .. c -- do not add \n to currentLine
				currentx = currentx + self:getFont():getWidth(c) 
				if currentx > w then
					currenty = currenty + height 
					currentx = self:getFont():getWidth(c) 
				end
			end
			if justFound then
				self.head = self.head .. c
				justFound = false; resultLine = currentLine
			elseif found then 
				self.trail = self.trail .. c
			else -- not found
				self.head = self.head .. c
			end
			i = i + 1 
		end	
		if not result then result = line end
		if not resultLine then resultLine = currentLine end

		io.write("=> select : line " .. result .. " \n")	
		io.write("=> selected text : '" .. resultLine .. "'\n")
		io.write("=> head : '" .. self.head .. "'\n")
		io.write("=> trail : '" .. self.trail .. "'\n")

		self.cursorLineOffset = -(result - 1)  		-- minus 1 because offset starts at 0, not 1
		local currentLineW = self:getFont():getWidth( resultLine )
		if currentLineW > self.w then
			self.xOffset = self.w - currentLineW
		else
			self.xOffset = 0 
		end
		self:setCursorPosition()

	end

	textActiveCallback = function(t) 
		self.head = self.head .. t 
		if t == "\n" then
			self.lineOffset = self.lineOffset + 1
			self.cursorLineOffset = self.cursorLineOffset - 1
			self.xOffset = 0
		--elseif fonts[12]:getWidth( self.head .. self.trail ) > self.w - fonts[12]:getWidth(t) then
		elseif self:getFont():getWidth( self:lastLine() .. t ) > self.w then
			self.xOffset = self.xOffset - self:getFont():getWidth(t)
		end 
		self:setCursorPosition() 
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
			self:setCursorPosition()
			if self.cursorPosition + self.xOffset < 0 then
				self.xOffset = self.xOffset + self:getFont():getWidth(remove)
			elseif self.cursorPosition + self.xOffset > self.w then
                        	self.xOffset = self.w - self.cursorPosition
                	end
		end
		end

	textActiveCopyCallback = function() 
		love.system.setClipboardText(self.textSelected)
		self.textSelected = ""; self.textSelectedPosition = 0; self.textSelectedCursorLineOffset = 0
		end

	textActivePasteCallback = function() 
		local t = love.system.getClipboardText( )
		self.head = self.head .. t
		self:setCursorPosition()
		if self.cursorPosition + self.xOffset > self.w then
			self.xOffset = - self.cursorPosition + self.w
		end
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
		self:setCursorPosition()
		if self.cursorPosition + self.xOffset < 0 then
			self.xOffset = self.xOffset + self:getFont():getWidth(remove)
		elseif self.cursorPosition + self.xOffset > self.w then
			self.xOffset = self.w - self.cursorPosition 
		end
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
		self:setCursorPosition()
		if self.cursorPosition + self.xOffset > self.w then
			self.xOffset = self.xOffset - self:getFont():getWidth(remove)
		elseif self.cursorPosition + self.xOffset < 0 then
			self.xOffset = 0 
		end
		end 

	end

function widget.textWidget:unselect() 
	if self.selected then 
		self.xOffset = 0
		self.lineOffset = 0
		self.cursorLineOffset = 0
		self.selected = false
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
  if self.selected then
    love.graphics.setColor(0,0,0)
    --love.graphics.rectangle("line",x/mag+zx,y/mag+zy-self.lineOffset*fontSize,self.w,self.h+self.lineOffset*fontSize, 5, 5)
    love.graphics.rectangle("line",x/mag+zx,y/mag+zy,self.w,self.h+self.lineOffset*self.fontHeight, 5, 5)
    love.graphics.setColor(unpack(self.backgroundColor))
    --love.graphics.rectangle("fill",x/mag+zx,y/mag+zy-self.lineOffset*fontSize,self.w,self.h+self.lineOffset*fontSize, 5, 5)
    love.graphics.rectangle("fill",x/mag+zx,y/mag+zy,self.w,self.h+self.lineOffset*self.fontHeight, 5, 5)
    love.graphics.setColor(0,0,0)
    if self.cursorDraw then 
	love.graphics.line(	self.cursorPosition + x/mag + zx + self.xOffset, 
				--y/mag+zy+self.cursorLineOffset*fontSize, 
				y/mag+zy-self.cursorLineOffset*self.fontHeight, 
				self.cursorPosition + x/mag + zx + self.xOffset, 
				--y/mag+zy+self.cursorLineOffset*fontSize+self.h
				y/mag+zy+self.h-self.cursorLineOffset*self.fontHeight
			  ) 
    end
  end
  love.graphics.setColor(unpack(self.color))
  love.graphics.setFont( self:getFont() )
  --love.graphics.setScissor(x/mag+zx,y/mag+zy-self.lineOffset*fontSize,self.w,self.h+self.lineOffset*fontSize)
  love.graphics.setScissor(x/mag+zx,y/mag+zy,self.w,self.h+self.lineOffset*self.fontHeight)
  --love.graphics.print(self.head..self.trail,math.floor(x/mag+zx+self.xOffset),math.floor(y/mag+zy-self.lineOffset*fontSize))
  love.graphics.print(self.head..self.trail,math.floor(x/mag+zx+self.xOffset),math.floor(y/mag+zy))
  if self.textSelected ~= "" then
    love.graphics.setColor(theme.color.red)
    --local w = self.cursorPosition - self.textSelectedPosition
    --love.graphics.rectangle("fill",x/mag+zx+self.textSelectedPosition+self.xOffset,y/mag+zy,w,self.h)
    love.graphics.line(		self.textSelectedPosition + x/mag + zx + self.xOffset, 
				y/mag+zy-self.textSelectedCursorLineOffset*self.fontHeight, 
				self.textSelectedPosition + x/mag + zx + self.xOffset, 
				y/mag+zy+self.h-self.textSelectedCursorLineOffset*self.fontHeight
			  ) 
  end
  love.graphics.setScissor()
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
  if self.bold then
  	return fontsBold[i]
  else
	return fonts[i]
  end
  end

function widget.textWidget:incFont()
  if self.fontSize < MAX_FONT_SIZE then 
	self.fontSize = self.fontSize + 1 
	self.fontHeight = self:getFont():getHeight()
	self:updateBaseHeight()
	self:setCursorPosition()
  end
  end

function widget.textWidget:decFont()
  if self.fontSize > MIN_FONT_SIZE then 
	self.fontSize = self.fontSize - 1 
	self.fontHeight = self:getFont():getHeight()
	self:updateBaseHeight()
	self:setCursorPosition()
  end
  end

function widget.textWidget:updateBaseHeight()
  self.h = self:getFont():getHeight()
  end

return widget

