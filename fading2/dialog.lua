
local utf8 	= require 'utf8'
local Window 	= require 'window'
local theme 	= require 'theme'

local dialogBase	= "Message: "
local dialog 		= dialogBase		-- text printed on the screen when typing dialog 
local dialogActive	= false
local dialogLog		= {}			-- store all dialogs for complete display
local ack		= false			-- automatic acknowledge when message received ?

-- Dialog class
-- a Dialog is a window which displays some text and let some input. it is not zoomable
local Dialog = Window:new{ class = "dialog" , title = "DIALOG WITH PLAYERS" }

function Dialog:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function Dialog:click(x,y) Window.click(self,x,y) end

function Dialog:addLine(l) table.insert( dialogLog, l ) end

function Dialog:draw()
   -- draw window frame
   love.graphics.setFont(theme.fontSearch)
   love.graphics.setColor(10,10,10,150)
   local zx,zy = -( self.x * 1/self.mag - self.layout.W / 2), -( self.y * 1/self.mag - self.layout.H / 2)
   love.graphics.rectangle( "fill", zx , zy , self.w , self.h )  
   -- print current log text
   local start
   if #dialogLog > 10 then start = #dialogLog - 10 else start = 1 end
   love.graphics.setColor(255,255,255)
   for i=start,#dialogLog do 
	love.graphics.printf( dialogLog[i] , zx , zy + (i-start)*18 , self.w )	
   end
   -- print MJ input eventually
   love.graphics.setColor(200,200,255)
   love.graphics.printf(dialog, zx , zy + self.h - 22 , self.w )

   -- print bar
   self:drawBar()
end

function Dialog:getFocus() 
	dialogActive = true
	textActiveCallback = function(t) dialog = dialog .. t end 
	textActiveBackspaceCallback = function ()
	 if dialog == dialogBase then return end
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

function Dialog:update(dt) Window.update(self,dt) end

-- send dialog message to player
function doDialog()
  local text = string.gsub( dialog, dialogBase, "" , 1) 
  dialog = dialogBase
  local _,_,playername,rest = string.find(text,"(%a+)%A?(.*)")
  io.write("send message '" .. text .. "': player=" .. tostring(playername) .. ", text=" .. tostring(rest) .. "\n")
  local tcp = findClientByName( playername )
  if not tcp then io.write("player not found or not connected\n") return end
  tcpsend( tcp, rest ) 
  table.insert( dialogLog , "MJ: " .. string.upper(text) .. "(" .. os.date("%X") .. ")" )
  end

return Dialog

