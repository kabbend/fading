
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
  new.cursorTimer = 0
  new.cursorTimerLimit = 0.5
  new.cursorPosition = 0
  new.cursorDraw = false
  -- text is splitted in 2, so we can place cursor
  new.head = t.text or ""
  new.trail = ""
  new.textSelected = ""
  new.textSelectedPosition = 0
  new.xOffset = 0
  new:setCursorPosition() 
  return new
  end

function widget.textWidget:select() 
	self.selected = true; 
	self.cursorTimer = 0

	textActiveCallback = function(t) 
		self.head = self.head .. t 
		if theme.fontRound:getWidth( self.head .. self.trail ) > self.w - theme.fontRound:getWidth(t) then
			self.xOffset = self.xOffset - theme.fontRound:getWidth(t)
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
			self:setCursorPosition()
			if self.cursorPosition + self.xOffset < 0 then
				self.xOffset = self.xOffset + theme.fontRound:getWidth(remove)
			end
		end
		end

	textActiveCopyCallback = function() 
		love.system.setClipboardText(self.textSelected)
		self.textSelected = ""; self.textSelectedPosition = 0
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
		self.trail = remove .. self.trail
		if love.keyboard.isDown("lshift") then
			if self.textSelected == "" then self.textSelectedPosition = self.cursorPosition end
			self.textSelected = remove .. self.textSelected
		else
			self.textSelected = "" ; self.textSelectedPosition = 0
		end
		self:setCursorPosition()
		if self.cursorPosition + self.xOffset < 0 then
			self.xOffset = self.xOffset + theme.fontRound:getWidth(remove)
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
		self.head = self.head .. remove 
		if love.keyboard.isDown("lshift") then
			if self.textSelected == "" then self.textSelectedPosition = self.cursorPosition end
			self.textSelected = self.textSelected .. remove
		else
			self.textSelected = "" ; self.textSelectedPosition = 0
		end
		self:setCursorPosition()
		if self.cursorPosition + self.xOffset > self.w then
			self.xOffset = self.xOffset - theme.fontRound:getWidth(remove)
		end
		end 

	end

function widget.textWidget:unselect() 
	if self.selected then 
		self.selected = false
		textActiveCallback = nil 
		textActiveBackspaceCallback = nil 
		textActivePasteCallback = nil 
		textActiveCopyCallback = nil 
		textActiveLeftCallback = nil 
		textActiveRightCallback = nil 
	end 
	end

function widget.textWidget:setCursorPosition()
  self.cursorPosition = theme.fontRound:getWidth( self.head ) 
  end

function widget.textWidget:getText() return self.head .. self.trail end

function widget.textWidget:click() self:select() end

function widget.textWidget:draw()
  local x,y = self.x, self.y
  local zx , zy = 0 , 0
  if self.parent then zx, zy = self.parent:WtoS(0,0) end
  if self.selected then
    love.graphics.setColor(255,255,255)
    love.graphics.rectangle("fill",x+zx,y+zy,self.w,self.h)
    love.graphics.setColor(0,0,0)
    if self.cursorDraw then 
	love.graphics.line(self.cursorPosition + x + zx + self.xOffset, y+zy, self.cursorPosition + x + zx + self.xOffset, y+zy+self.h) 
    end
  end
  love.graphics.setColor(0,0,0)
  love.graphics.setFont( theme.fontRound )
  love.graphics.setScissor(x+zx,y+zy,self.w,self.h)
  love.graphics.print(self.head..self.trail,x+zx+self.xOffset,y+zy)
  if self.textSelected ~= "" then
    love.graphics.setColor(155,155,155,155)
    local w = self.cursorPosition - self.textSelectedPosition
    love.graphics.rectangle("fill",x+zx+self.textSelectedPosition+self.xOffset,y+zy,w,self.h)
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

return widget

