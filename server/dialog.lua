
local utf8 	= require 'utf8'
local Window 	= require 'window'
local theme 	= require 'theme'
local json	= require 'json'
local http	= require 'socket.http'
local ltn12	= require 'ltn12'

local dialogBase		= "Your input:"
local dialog 			= ""			-- text printed on the screen when typing dialog 
local dialogActive		= false
local dialogLog			= {}			-- store all dialogs for complete display
local dialogHistory		= {}
local dialogHistoryIndex 	= 2
local ack			= false			-- automatic acknowledge when message received ?

local lines		= 10
local columns		= 24
local selectAll		= false

-- Dialog class
-- a Dialog is a window which displays some text and let some input. it is not zoomable
local Dialog = Window:new{ class = "dialog" , title = "DIALOG", wResizable = true, hResizable = true , buttons = { 'always', 'close' } }

function Dialog:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  self.users = {} -- a user is made of : s = snapshot, class = classname (username), recipient = flag true/false
  return new
end

function Dialog:getSession()
  local b, s = http.request(URL)
  if b then
	io.write(b)
  	table.insert( dialogLog , b )
  else
  	table.insert( dialogLog , "unexpected error. cannot get session" )
  end
  end

function Dialog:createSession()
  local str = '{"ip":"' .. myIP .. '","key":"' .. licensekey .. '"}'
  local cl = string.len(str)
  io.write("dialog.lua: about to request session for : " .. str .. "\n")
  local r, c, h = http.request {
   method = "POST",
   url = URL,
   headers = { ["Content-Type"] = "application/json" , ["content-length"] = tostring(cl) },
   source = ltn12.source.string(str)
  }
  if r==1 and c == 200 then
  	table.insert( dialogLog , c .. " session created successfully" )
  else
  	table.insert( dialogLog , tostring(c) .. " unable to create session" )
  end
end

function Dialog:deleteSession()
  local r, c, h = http.request {
   method = "DELETE",
   url = URL,
  }
  if c == 200 then
  	table.insert( dialogLog , c .. " session deleted successfully" )
  else
  	table.insert( dialogLog , tostring(c) .. " something unexpected occurred" )
  end
  end

function Dialog:drop( o )
  if o.object.class == "text" then
	local t = o.object.text
	dialog = t.text
	self:doDialog()		
  end
  end

function Dialog:click(x,y) 

   	local zx,zy = -( self.x * 1/self.mag - self.layout.W / 2), -( self.y * 1/self.mag - self.layout.H / 2)
	if (y >= zy and y < zy + layout.snapshotSize + layout.snapshotMargin * 2 + 16) then
		local index = math.floor( (x - zx) / (layout.snapshotSize + layout.snapshotMargin) ) 
		if index <= #self.users then
			if index == 0 then
				selectAll = not selectAll
				if selectAll then
					for i=1,#self.users do
						self.users[i].recipient = selectAll	
					end	
				end
			else
				selectAll = false
				self.users[index].recipient = not self.users[index].recipient	
			end
		end
	else
		Window.click(self,x,y) 
	end
   end

function Dialog:addLine(l) table.insert( dialogLog, l ) end

function Dialog:registerCallingUser( class )
   local s = layout.snapshotWindow:getCallingUser( class )
   io.write("registering " .. class .. "\n")
   if not s then 	
	io.write("registering " .. class .. " : not found. Setting to default\n"); 
   	table.insert( self.users , { s = { thumb = theme.dialogUnknown } , class = class , recipient = false } )
   else
   	table.insert( self.users , { s = s, class = class , recipient = false } )
   end
   return true
   end

function Dialog:draw()

   local zx,zy = -( self.x * 1/self.mag - self.layout.W / 2), -( self.y * 1/self.mag - self.layout.H / 2)
   love.graphics.setFont(fontsBold[16])

   -- draw window frame
   love.graphics.setColor(250,250,250,mainAlpha)
   love.graphics.rectangle( "fill", zx , zy , self.w , self.h )  

   love.graphics.setColor(5,5,5,10)
   love.graphics.rectangle( "fill", zx , zy , self.w , layout.snapshotSize + layout.snapshotMargin * 2 + 16 )  

   -- print All button
   if not selectAll then love.graphics.setColor(255,255,255) else love.graphics.setColor(0,0,0) end
   love.graphics.draw( theme.dialogAll , zx + layout.snapshotMargin + 10 , zy + layout.snapshotMargin + 4)
   if selectAll then love.graphics.setColor(0,0,0) else love.graphics.setColor(0,0,0,120) end
   love.graphics.print( "(all)" , zx + layout.snapshotMargin + 30  , zy + layout.snapshotMargin + layout.snapshotSize)

   -- print users
   local usersH = layout.snapshotSize + layout.snapshotMargin * 3
   for i=1,#self.users do
 	u = self.users[i]
   	if u.recipient then love.graphics.setColor(255,255,255) else love.graphics.setColor(255,200,200,120) end
	love.graphics.draw( u.s.thumb , zx + layout.snapshotMargin + i*usersH , zy + layout.snapshotMargin )
   	if u.recipient then love.graphics.setColor(0,0,0) else love.graphics.setColor(0,0,0,120) end
	love.graphics.print( u.class , zx + layout.snapshotMargin + i*usersH + 10 , zy + layout.snapshotMargin + layout.snapshotSize )
   end
   
   -- print current log text
   local start
   --if #dialogLog > 10 then start = #dialogLog - 10 else start = 1 end
   love.graphics.setColor(0,0,0)
   -- print all lines in reverse order. stop if outside window
   local height = 0
   for i=#dialogLog,1,-1 do 
	height = height + math.ceil(theme.fontSearch:getWidth(dialogLog[i]) / self.w) 
	local y = self.h - 22 - height * 22  - 5 * (#dialogLog - i + 1)
	if y < usersH then break end
	love.graphics.printf( dialogLog[i] , zx , zy + y , self.w )	
   end
   -- print MJ line 
   love.graphics.setColor(5,5,150,100)
   love.graphics.rectangle( "fill", zx , zy + self.h - 26  , self.w , 26 )  
   love.graphics.setColor(0,0,0)
   love.graphics.printf(dialog, zx , zy + self.h - 22 , self.w )

   -- print bar and rest
   self:drawBar()
   self:drawResize()

end

function Dialog:getFocus() 
	dialogActive = true
	textActiveCallback = function(t) if t == '\n' then self:doDialog() else dialog = dialog .. t end end 
	textActiveBackspaceCallback = function ()
	 if dialog == "" then return end
         -- get the byte offset to the last UTF-8 character in the string.
         local byteoffset = utf8.offset(dialog, -1)
         if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            dialog = string.sub(dialog, 1, byteoffset - 1)
         end
	end
	end

function Dialog:looseFocus() 
	dialogActive = false 
	textActiveCallback = nil
	textActiveBackspaceCallback = nil
	end

function Dialog:goPreviousHistory()
	local index = dialogHistoryIndex - 1
	if index < 1 then return end
	dialogHistoryIndex = index
	dialog = dialogHistory[dialogHistoryIndex]
  	end

function Dialog:goNextHistory()
	local index = dialogHistoryIndex + 1
	if index > #dialogHistory then dialog = ""; return end
	dialogHistoryIndex = index
	dialog = dialogHistory[dialogHistoryIndex]
  	end

function Dialog:goLastHistory()
	dialogHistoryIndex = #dialogHistory + 1
	end

function Dialog:update(dt) Window.update(self,dt) end

-- send dialog message to player
function Dialog:doDialog()

  local text = dialog 
  dialog = ""

  -- do nothing with empty text...
  if text == "" then table.insert( dialogLog , " ") ; return end

  -- historize
  table.insert( dialogHistory, text )
  dialogHistoryIndex = #dialogHistory + 1

  -- internal command or message ?
  if text == "/getsession" then
	self:getSession()
  elseif text == "/session" then
	self:createSession()
  elseif text == "/killsession" then
	self:deleteSession()
  else
   local atLeastOne = false
   for i=1,#self.users do
	if self.users[i].recipient then
		atLeastOne = true
  		local tcp = findClientByName( self.users[i].class )
  		if not tcp then 
			io.write("player not found or not connected\n") 
  			table.insert( dialogLog , ">> missing playername or player not connected..." )
  		end
		local msg = { t = text , caller = "MJ" }
		local encodedMessage  = json.encode( msg )
  		tcpsend( tcp, encodedMessage ) 
  		table.insert( dialogLog , "MJ -> " .. self.users[i].class .. ": " .. text )
	end
    end
    if not atLeastOne then
	-- message was sent to nobody.. tell the MJ
  	table.insert( dialogLog , "! No recipient ! : " .. text )
	
    end
  end

end

local baseH1 = layout.snapshotSize + layout.snapshotMargin * 3 + 22 * 4
local baseH2 = layout.snapshotSize + layout.snapshotMargin * 3

function Dialog:liveResize()
	if self.w < 200 then self.w = 200 end
	if self.h < baseH1 then self.h = baseH1 end
end

function Dialog:resize()
	self.h = baseH1 + math.max(4, math.floor((self.h - baseH1) / 22)) * 22
end

return Dialog

