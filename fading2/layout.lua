
--
-- mainLayout class
-- store all windows, with their display status (displayed or not) and layer value
--
local mainLayout = {}

function mainLayout:new()
  local new = { windows= {}, maxWindowLayer = 1 , focus = nil, sorted = {} }
  setmetatable( new , self )
  self.__index = self
  self.globalDisplay = true
  return new
end

function mainLayout:addWindow( window, display , name ) 
	if window.alwaysBottom then
		self.windows[window] = { w=window , l=1 , d=display }
	elseif window.alwaysOnTop then
		self.windows[window] = { w=window , l=10e10 , d=display }
	else
		self.maxWindowLayer = self.maxWindowLayer + 1
		self.windows[window] = { w=window , l=self.maxWindowLayer , d=display }
	end
	-- sort windows by layer (ascending) value
	table.insert( self.sorted , self.windows[window] )
	table.sort( self.sorted , function(a,b) return a.l < b.l end )
	window.startupX, window.startupY, window.startupMag = window.x, window.y, window.mag

	-- if a name if given, store it by name also, so it can be retrieved easily by calling that name from the layout object
	if name then self[name] = window end

	end

-- restore a window to its default value
function mainLayout:restoreBase(window)
	window.x, window.y, window.mag = window.startupX, window.startupY, window.startupMag
	self.windows[window].d = true
	end

function mainLayout:removeWindow( window ) 
	if self.focus == window then self:setFocus( nil ) end
	for i=1,#self.sorted do if self.sorted[i].w == window then table.remove( self.sorted , i ); break; end end
	self.windows[window] = nil
	end

-- request a window to be on top, or restore it to its standard mode
function mainLayout:setOnTop( window , onTop )
	if not onTop then 
		layout.windows[window].l = layout.maxWindowLayer+1
	else 
		layout.windows[window].l = 10e5
	end
	table.sort( self.sorted , function(a,b) return a.l < b.l end )
	end

-- manage display status of a window
function mainLayout:setDisplay( window, display ) 
	if self.windows[window] then 
		self.windows[window].d = display
		if not display and self.focus == window then self:setFocus(nil) end -- looses the focus as well
	end
	end 
	
function mainLayout:getDisplay( window ) if self.windows[window] then return self.windows[window].d else return false end end

-- we can set a global value to display, or hide, all windows in one shot
function mainLayout:toggleDisplay() 
	self.globalDisplay = not self.globalDisplay 
 	if not self.globalDisplay then self:setFocus(nil) end -- no more window focus	
	end

function mainLayout:toggleWindow(w)
	self.windows[w].d = not self.windows[w].d
	end

function mainLayout:hideAll()
	for i=1,#self.sorted do if not self.sorted[i].w.alwaysVisible then self.sorted[i].d = false end end
	end

-- return (if there is one) or set the window with focus 
-- if we set focus, the window automatically gets in front layer
function mainLayout:getFocus() return self.focus end

-- set the focus on the given window. if window is nil, remove existing focus if any
function mainLayout:setFocus( window ) 
	if window then
		if window == self.focus then return end -- this window was already in focus. nothing happens
		if not window.alwaysBottom and not window.alwaysOnTop then
			self.maxWindowLayer = self.maxWindowLayer + 1
			self.windows[window].l = self.maxWindowLayer
			table.sort( self.sorted , function(a,b) return a.l < b.l end )
		end
		window:getFocus()
		if self.focus then self.focus:looseFocus() end
	end
	if not window and self.focus then self.focus:looseFocus() end
	self.focus = window
	end 

-- when ctrl+tab is pressed, select the next window to put focus on
function mainLayout:nextWindow()
 	local t = {}
	local index  = nil
	if not self.globalDisplay then return end
	for w,v in pairs(self.windows) do if v.d and w.class ~= "icon" and w.class ~= "roll" and w.class ~= "notification" then 
		table.insert( t , w ) 
		if w == self:getFocus() then index = #t end
		end end
	if not index then
		if #t >= 1 then index = 1
		else return end
	end
 	index = index + 1
	if index > #t then index = 1 end	
	self:setFocus( t[index] )	
	end

-- check if there is (and return) a window present at the given position in the screen
-- this takes into account the fact that a window is displayed or not (of course) but
-- also the layer value (the window with highest layer is selected).
-- If a window is actually clicked, it automatically gets focus and will get in front.
-- If no window is clicked, they all loose the focus
function mainLayout:click( x , y )
	local layer = 0
	local result = nil
	for k,l in pairs( self.windows ) do
		-- in ESC mode, no window at all excepts icons
		if self.globalDisplay or l.w.alwaysVisible then 
			if l.d and l.w:isInside(x,y) and l.l > layer then result = l.w ; layer = l.l end  
		end
	end
	if result then
		-- a window was actually clicked. Call corresponding click() function 
		-- this gives opportunity to the window to react, and potentially to close itself
		-- if the close button is pressed. 
		result:click(x,y)
		if not result.markForClosure then self:setFocus( result ) end -- this gives focus
	else
		self:setFocus(nil)
	end
	return result
	end

-- same as click function, except that no click is actually performed, so focus does not change
function mainLayout:getWindow( x , y )
	local layer = 0
	local result = nil
	for k,l in pairs( self.windows ) do
		-- in ESC mode, no window at all excepts icons
		if self.globalDisplay or l.w.alwaysVisible then 
			if l.d and l.w:isInside(x,y) and l.l > layer then result = l.w ; layer = l.l end  
		end
	end
	return result
	end

function mainLayout:draw() 
	for k,v in ipairs( self.sorted ) do 
		if self.globalDisplay or v.w.alwaysVisible then
			if self.sorted[k].d then self.sorted[k].w:draw() end 
		end
	end
	end 

function mainLayout:update(dt)
	for k,v in pairs(self.windows) do v.w:update(dt) end
	end

function mainLayout:mousemoved(x,y,dx,dy)
	for k,v in pairs(self.windows) do if v.w.mousemoved then v.w:mousemoved(x,y,dx,dy) end end 
	end

function mainLayout:mousereleased(x,y)
	for k,v in pairs(self.windows) do if v.w.mousereleased then v.w:mousereleased(x,y) end end 
	end

return mainLayout

