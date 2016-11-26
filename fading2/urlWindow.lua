
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	
local Snapshot		= require 'snapshot'

--
-- urlWindow class
--
local urlWindow = Window:new{ class = "url",
			      title = "Please enter an image URL" }

function urlWindow:new( t ) -- create from w, h, x, y, init
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.widgets = {}
  new.path = t.path
  new.text = widget.textWidget:new{ x = 5, y = 5 , w = 850, text = "http://" }
  new:addWidget( new.text )
  new.load = widget.buttonWidget:new{ x = 880, y = 2 , w = 100, text = "Download" }
  new:addWidget( new.load )
  return new
end

function urlWindow:draw()
  self:drawBack()
  self:drawWidgets()
  self:drawBar()
  end

function urlWindow:loadURL()

  local url = self.text:getText()

  -- load and check result
  local http = require("socket.http")
  local b, c = http.request( url )
  io.write("downloading " .. url .. " HTTP status = " .. tostring(c) .. "\n")
  if (not b) or (c ~= 200) then
	layout.notificationWindow:addMessage("HTTP status " .. c .. ". Could not load image at " .. url )
	return 
  end

  -- write it to a file
  local filename = self.path .. "downloadImage"
  local f = io.open(filename,"w")
  f:write(b)
  f:close()

  -- store the content of the file to a snapshot
  local csnap = layout.snapshotWindow.currentSnap
  local s = nil
  if csnap == 2 then
	-- loading a map
  else
	-- loading something else
  	s = Snapshot:new{ filename = filename , size = self.layout.snapshotSize, nomipmaps = true }
  end
  if not s then 
	layout.notificationWindow:addMessage("Could not load image at " .. url ); return 
  else
	io.write("w,h,snapmag=" .. tostring(s.w) .. " " .. tostring(s.h) .. " " .. tostring(s.snapmag) .. "\n")
	layout.notificationWindow:addMessage("Image loaded, " .. url )
  	io.write("adding image " .. url .. " to snapshotBar list #" .. csnap .. "\n") 
  	table.insert( layout.snapshotWindow.snapshots[csnap].s , s )  
  end
  end

function urlWindow:click(x,y)
  Window.click(self,x,y)
  if self.text:isInside(x,y) then self.text:select() else self.text:unselect() end 
  if self.load:isInside(x,y) then self:loadURL() end 
  end

function urlWindow:update(dt)
  for i=1,#self.widgets do self.widgets[i]:update(dt) end
  end

return urlWindow

