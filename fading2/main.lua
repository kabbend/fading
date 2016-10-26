
-- interface import
local yui 	= require 'yui.yaoui' 	-- Graphical library on top of Love2D
local socket 	= require 'socket'
local utf8 	= require 'utf8'
local parser    = require 'parse'

-- dice3d code
require	'base'
require 'loveplus'
require 'vector'
require 'render'
require 'stars'
require 'geometry'
require 'diceview'
require 'light'
require 'default/config'

--
-- GLOBAL VARIABLES
--

debug = false

-- main layout
layout = nil
currentWindowDraw = nil

-- tcp information for network
address, serverport	= "*", "12345"		-- server information
server			= nil			-- server tcp object
ip,port 		= nil, nil		-- projector information
clients			= {}			-- list of clients. A client is a couple { tcp-object , id } where id is a PJ-id or "*proj"
projector		= nil			-- direct access to tcp object for projector
projectorId		= "*proj"		-- special ID to distinguish projector from other clients
chunksize 		= (8192 - 1)		-- size of the datagram when sending binary file
chunkrepeat 		= 6			-- number of chunks to send before requesting an acknowledge

-- main screen size
W, H = 1420, 790 	-- main window size default values (may be changed dynamically on some systems)
viewh = H - 170 	-- view height
vieww = W - 300		-- view width
size = 19 		-- base font size
margin = 20		-- screen margin in map mode

-- messages zone
messages 		= {}
messagesH		= H - 22

-- snapshots
snapshots    = {}
snapshots[1] = { s = {}, index = 1, offset = 0 } 	-- small snapshots at the bottom, for general images
snapshots[2] = { s = {}, index = 1, offset = 0 }	-- small snapshots at the bottom, for scenario & maps
snapshots[3] = { s = {}, index = 1, offset = 0 }	-- small snapshots at the bottom, for pawns
currentSnap		= 1				-- by default, we display images
snapshotSize 		= 70 				-- w and h of each snapshot
snapshotMargin 		= 7 				-- space between images and screen border
snapshotH 		= messagesH - snapshotSize - snapshotMargin

-- pawns and PJ snapshots
pawnMove 		= nil		-- pawn currently moved by mouse movement
defaultPawnSnapshot	= nil		-- default image to be used for pawns
pawnMaxLayer		= 1

-- snapshot size and image
H1, W1 = 140, 140
currentImage = nil

-- some GUI buttons whose color will need to be 
-- changed at runtime
attButton	= nil		-- button Roll Attack
armButton	= nil		-- button Roll Armor
nextButton	= nil		-- button Next Round
clnButton	= nil		-- button Cleanup
thereIsDead	= false		-- is there a dead character in the list ? (if so, cleanup button is clickable)

-- maps & scenario stuff
textBase		= "Search: "
text 			= textBase		-- text printed on the screen when typing search keywords
searchActive		= false
ignoreLastChar		= false
searchIterator		= nil			-- iterator on the results, when search is done
searchPertinence 	= 0			-- will be set by using the iterator, and used during draw
searchIndex		= 0			-- will be set by using the iterator, and used during draw
searchSize		= 0 			-- idem
dictionnary 		= {}			-- dictionnary indexed by word, with value a couple position (string) 
						-- and level (integer) as in { "((x,y))", lvl } 
keyZoomIn		= ':'			-- default on macbookpro keyboard. Changed at runtime for windows
keyZoomOut 		= '=' 			-- default on macbookpro keyboard. Changed at runtime for windows

-- dialog stuff
dialogBase		= "Message: "
dialog 			= dialogBase		-- text printed on the screen when typing dialog 
dialogActive		= false
dialogLog		= {}			-- store all dialogs for complete display
displayDialogLog	= false
ack			= false			-- automatic acknowledge when message received ?

-- some basic colors
color = {
  masked = {210,210,210}, black = {0,0,0}, red = {250,80,80}, darkblue = {66,66,238}, purple = {127,0,255}, 
  orange = {204,102,0},   darkgreen = {0,102,0},   white = {255,255,255} } 

-- array of PNJ templates (loaded from data file)
templateArray 	= {}		

-- array of actual PNJs, from index 1 to index (PNJnum - 1)
-- None at startup (they are created upon user request)
-- Maximum number is PNJmax
-- At a given time, number of PNJs is (PNJnum - 1)
-- A Dead PNJ counts as 1, except if explicitely removed from the list
PNJTable 	= {}		
PNJnum 		= 1		-- next index to use in PNJTable 
PNJmax   	= 13		-- Limit in the number of PNJs (and the GUI frame size as well)

-- Direct access (without traversal) to GUI structure:
-- PNJtext[i] gives a direct access to the i-th GUI line in the GUI PNJ frame
-- this corresponds to the i-th PNJ as stored in PNJTable[i]
PNJtext 	= {}		

-- Round information
roundTimer	= 0
roundNumber 	= 1			
newRound	= true

-- flash flag and timer when 'next round' is available
flashTimer	= 0
nextFlash	= false
flashSequence	= false

-- in combat mode, a given PNJ line may have the focus
focus	        = nil   -- Index (in PNJTable) of the current PNJ with focus (or nil if no one)
focusTarget     = nil   -- unique ID (and not index) of the corresponding target
focusAttackers  = {}    -- List of unique IDs of the corresponding attackers
lastFocus	= nil	-- store last focus value

-- flag and timer to draw d6 dices in combat mode
dice 		    = {}	-- list of d6 dices
drawDicesTimer      = 0
drawDices           = false	-- flag to draw dices
drawDicesResult     = false	-- flag to draw dices result (in a 2nd step)	
diceKind 	    = ""	-- kind of dice (black for 'attack', white for 'armor')
diceSum		    = 0		-- result to be displayed on screen
lastDiceSum	    = 0		-- store previous result
diceStableTimer	    = 0

-- information to draw the arrow in combat mode
arrowMode 		 = false	-- draw an arrow with mouse, yes or no
arrowStartX, arrowStartY = 0,0		-- starting point of the arrow	
arrowX, arrowY 		 = 0,0		-- current end point of the arrow
arrowStartIndex 	 = nil		-- index of the PNJ at the starting point
arrowStopIndex 		 = nil		-- index of the PNJ at the ending point
arrowModeMap		 = nil		-- either nil (not in map mode), "RECT" or "CIRC" shape used to draw map maskt
maskType		 = "RECT"	-- shape to use, rectangle by default


--[[
-- we assume that we provide the upper left corner of each rectangle, 
-- and positive values for height and width
function isRectACoveredByRectB(ax,ay,aw,ah,bx,by,bw,bh)
  return ax >= bx and ay >= by and (ax + aw <= bx + bw) and (ay + ah <= by + bh)
end

function isRectACoveredByCircleB(ax,ay,aw,ah,bx,by,br)
  return distanceFrom(ax,ay,bx,by) <= br and
		 distanceFrom(ax+aw,ay,bx,by) <= br and
		 distanceFrom(ax,ay+ah,bx,by) <= br and
		 distanceFrom(ax+aw,ay+ah,bx,by) <= br
end

function isCircleBCoveredByRectA(ax,ay,aw,ah,bx,by,br)
  if 2*br > aw or 2*br > ah then return false end
  local interiorw, interiorh = aw - 2*br, ah - 2*br
  local interiorx, interiory = ax + br, ay + br
  return bx >= interiorx and bx <= interiorx + interiorw and
		 by >= interiory and by <= interiory + interiorh
end

function isCircleACoveredByCircleB(ax,ay,ar,bx,by,br)
  local d = distanceFrom(ax,ay,bx,by)
  return (d + ar) <= br 
end
--]]

--
-- Multiple inheritance mechanism
-- call CreateClass with any number of existing classes 
-- to create the new inherited class
--

-- look up for `k' in list of tables `plist'
function Csearch (k, plist)
for i=1, table.getn(plist) do
local v = plist[i][k] -- try `i'-th superclass
if v then return v end
end
end

function createClass (a,b)
local c = {} -- new class
-- class will search for each method in the list of its
-- parents (`arg' is the list of parents)
setmetatable(c, {__index = function (t, k) return Csearch(k, {a,b}) end})
-- prepare `c' to be the metatable of its instances
c.__index = c
-- define a new constructor for this new class
function c:new (o) o = o or {}; setmetatable(o, c); return o end
-- return new class
return c
end

function loadDistantImage( filename )
  local file = assert( io.open( filename, 'rb' ) )
  local image = file:read('*a')
  file:close()
  return image  
end

function loadLocalImage( file )
  file:open('r')
  local image = file:read()
  file:close()
  return image
end

-- Snapshot class
-- a snapshot holds an image, displayed in the bottom part of the screen.
-- Snapshots are used for general images, and for pawns. For maps, use the
-- specific class Map instead, which is derived from Snapshot.
-- The image itself is stored in memory in its binary form, but for purpose of
-- sending it to the projector, it is also either stored as a path on the shared 
-- filesystem, or a file object on the local filesystem
Snapshot = { class = "snapshot" , filename = nil, file = nil }
function Snapshot:new( t ) -- create from filename or file object (one mandatory)
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  assert( new.filename or new.file )
  local image
  if new.filename then 
	image = loadDistantImage( new.filename )
	new.is_local = false
	new.baseFilename = string.gsub(new.filename,baseDirectory,"")
  else 
	image = loadLocalImage( new.file )
	new.is_local = true
	new.baseFilename = nil
  end
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)
  new.im = img
  new.w, new.h = new.im:getDimensions()
  local f1, f2 = snapshotSize / new.w, snapshotSize / new.h
  new.snapmag = math.min( f1, f2 )
  new.selected = false
  return new
end


-- Window class
-- a window is here an object slightly different from common usage, because
-- * a window may have the property to be zoomable, dynamically at runtime. This
--   is not the same as resizable, as its scale then changes (not only its frame)
--   For this reason, the important information about coordinates is not the
--   classical position (x,y) associated to the upper left corner of the window 
--   within the screen coordinate-system, but the point within the window itself,
--   expressed in the window-coordinate system, which is currently displayed at
--   the center of the screen (see the difference?). This point is an invariant
--   when the window zooms in or out.
-- * w and h are respectively width and height of the window, in pixels, but
--   expressed for the window at scale 1 (no zoom in or out). These dimensions
--   are absolute and will not change during the lifetime of the window object,
--   only the scaling factor will change to reflect a bigger (or smaller) object
--   actually drawn on the screen 
-- Notes:
-- Each object derived from Window class should redefine its own draw(), getFocus()
-- and looseFocus() methods.
-- Windows are gathered and manipulated thru the mainLayout object.
-- The main screen of the application (with yui view, etc.) is not considered as
--   a window object. For the moment, only scenario, maps and logs are windows,
--   and are displayed "on top" of this main screen.
--
Window = { class = "window", w = 0, h = 0, mag = 1.0, x = 0, y = 0 , zoomable = false }
function Window:new( t ) 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

-- return true if the point (x,y) (expressed in layout coordinates system,
-- typically the mouse), is inside the window frame (whatever the display or
-- layer value, managed at higher-level)
function Window:isInside(x,y)
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  return x >= zx and x <= zx + self.w / self.mag and 
  	 y >= zy and y <= zy + self.h / self.mag
end

function Window:zoom( mag ) if self.zoomable then self.mag = mag end end
function Window:move( x, y ) self.x = x; self.y = y; end
function Window:draw() end
function Window:getFocus() end
function Window:looseFocus() end

-- Map class
-- a Map inherits from Window and from Snapshot, and is referenced both 
-- in the Atlas and in the snapshots list
-- It has the following additional properties
-- * it displays a jpeg image, a map, on which we can put and move pawns
-- * it can be of kind "map" (the default) or kind "scenario"
-- * it can be visible, meaning it is displayed to the players on
--   the projector, in realtime. There is maximum one visible map at a time
--   (but there may be several maps displayed on the server, to the MJ)
Map = createClass( Window , Snapshot )
function Map:load( t ) -- create from filename or file object (one mandatory). kind is optional
  local t = t or {}
  if not t.kind then self.kind = "map" else self.kind = t.kind end 
     -- a map by default. A scenario should be declared by the caller
  --setmetatable( new , self )
  --self.__index = self
  self.class = "map"
  
  -- snapshot part of the object
  assert( t.filename or t.file )
  local image
  if t.filename then
	self.filename = t.filename 
	image = loadDistantImage( self.filename )
	self.is_local = false
	self.baseFilename = string.gsub(self.filename,baseDirectory,"")
  else 
	self.file = t.file
	image = loadLocalImage( self.file )
	self.is_local = true
	self.baseFilename = nil
  end
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)
  self.im = img
  self.w, self.h = self.im:getDimensions()
  local f1, f2 = snapshotSize / self.w, snapshotSize / self.h
  self.snapmag = math.min( f1, f2 )
  self.selected = false
  
  -- window part of the object
  self.zoomable = true
  self.x = self.w / 2
  self.y = self.h / 2
  self.mag = 1.0
  
  -- specific to the map itself
  if self.kind == "map" then self.mask = {} else self.mask = nil end
  self.step = 50
  self.pawns = {}
end

function Map:draw()

     local map = self
     currentWindowDraw = self

     local SX,SY,MAG = map.x, map.y, map.mag
     local x,y = -( SX * 1/MAG - W / 2), -( SY * 1/MAG - H / 2)

     if map.mask then	
       love.graphics.setColor(100,100,50,200)
       love.graphics.stencil( myStencilFunction, "increment" )
       love.graphics.setStencilTest("equal", 1)
     else
       love.graphics.setColor(255,255,255,240)
     end

     love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )

     if map.mask then
       love.graphics.setStencilTest("gequal", 2)
       love.graphics.setColor(255,255,255)
       love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )
       love.graphics.setStencilTest()
     end

     -- draw small circle or rectangle in upper corner, to show which mode we are in
     if map.kind == "map" then
       love.graphics.setColor(200,0,0,180)
       if maskType == "RECT" then love.graphics.rectangle("line",x + 5, y + 5,20,20) end
       if maskType == "CIRC" then love.graphics.circle("line",x + 15, y + 15,10) end
     end

     -- draw pawns, if any
     if map.pawns then
	     for i=1,#map.pawns do
       	     	     local index = findPNJ(map.pawns[i].id) 
		     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn 
		     -- is dead, or, worse, has been removed completely from the list
		     if index then 
		     	local dead = false
		     	dead = PNJTable[ index ].is_dead
		     	if map.pawns[i].im then
  		       		local zx,zy = (map.pawns[i].x) * 1/map.mag + x , (map.pawns[i].y) * 1/map.mag + y
		       		if PNJTable[index].PJ then love.graphics.setColor(50,50,250) else love.graphics.setColor(250,50,50) end
		       		love.graphics.rectangle( "fill", zx, zy, (map.pawns[i].size+6) / map.mag, (map.pawns[i].size+6) / map.mag)
		       		if dead then love.graphics.setColor(50,50,50,200) else love.graphics.setColor(255,255,255) end
		       		zx = zx + map.pawns[i].offsetx / map.mag
		       		zy = zy + map.pawns[i].offsety / map.mag
		       		love.graphics.draw( map.pawns[i].im , zx, zy, 0, map.pawns[i].f / map.mag , map.pawns[i].f / map.mag )
	     	     	end
		     end
	     end
     end

     -- print visible 
     if atlas:isVisible( map ) then
        love.graphics.setColor(200,0,0,180)
        love.graphics.setFont(fontDice)
	love.graphics.printf("V", x + map.w / map.mag - 65 , y + 5 ,500)
     end

end

function Map:getFocus() if self.kind == "scenario" then searchActive = true end end
function Map:looseFocus() if self.kind == "scenario" then searchActive = false end end

-- Dialog class
-- a Dialog is a window which displays some text and let some input. it is not zoomable
Dialog = Window:new{ class = "dialog" }

function Dialog:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function Dialog:draw()
   love.graphics.setFont(fontSearch)
   love.graphics.setColor(10,10,10,150)
   local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
   love.graphics.rectangle( "fill", zx , zy , self.w , self.h )  
   local start
   if #dialogLog > 12 then start = #dialogLog - 12 else start = 1 end
   love.graphics.setColor(255,255,255)
   for i=start,#dialogLog do 
	love.graphics.printf( dialogLog[i] , zx , zy + (i-start)*18 , self.w )	
   end
end

function Dialog:getFocus() dialogActive = true end
function Dialog:looseFocus() dialogActive = false end

-- mainLayout class
-- store all windows, with their display status (displayed or not) and layer value
mainLayout = {}
function mainLayout:new()
  local new = { windows= {}, maxWindowLayer = 1 , focus = nil, sorted = {} }
  setmetatable( new , self )
  self.__index = self
  return new
end

function mainLayout:addWindow( window, display ) 
	self.maxWindowLayer = self.maxWindowLayer + 1
	self.windows[window] = { w=window , l=self.maxWindowLayer , d=display }
	-- sort windows by layer (ascending) value
	table.insert( self.sorted , self.windows[window] )
	table.sort( self.sorted , function(a,b) return a.l < b.l end )
	end

function mainLayout:removeWindow( window ) 
	if self.focus == window then self:setFocus( nil ) end
	for i=1,#self.sorted do if self.sorted[i].w == window then table.remove( self.sorted , i ); break; end end
	self.windows[window] = nil
	end

-- manage display status of a window
function mainLayout:setDisplay( window, display ) 
	if self.windows[window] then 
		self.windows[window].d = display
		if not display and self.focus == window then self:setFocus(nil) end -- looses the focus as well
	end
	end 
	
function mainLayout:getDisplay( window ) if self.windows[window] then return self.windows[window].d else return false end end

-- return (if there is one) or set the window with focus 
-- if we set focus, the window automatically gets in front layer
function mainLayout:getFocus() return self.focus end
function mainLayout:setFocus( window ) 
	if window then
		if window == self.focus then return end -- this window was already in focus. nothing happens
		self.maxWindowLayer = self.maxWindowLayer + 1
		self.windows[window].l = self.maxWindowLayer
		table.sort( self.sorted , function(a,b) return a.l < b.l end )
		window:getFocus()
		if self.focus then self.focus:looseFocus() end
	end
	if not window and self.focus then self.focus:looseFocus() end
	self.focus = window
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
		if l.d and l.w:isInside(x,y) and l.l > layer then result = l.w ; layer = l.l end  
	end
	self:setFocus( result ) -- this gives or removes focus
	return result
	end

function mainLayout:draw() 
	for k,v in ipairs( self.sorted ) do if self.sorted[k].d then self.sorted[k].w:draw() end end
end 


local oldiowrite = io.write
function io.write( data ) if debug then oldiowrite( data ) end end

-- insert a new message to display
function addMessage( text, time , important )
  if not time then time = 5 end
  table.insert( messages, { text=text , time=time, offset=0, important=important } )
end
 
-- send a command or data to the projector over the network
function tcpsend( tcp, data , verbose )
  if not tcp then return end -- no client connected yet !
  if verbose == nil or verbose == true then  io.write("send to " .. tcp:getpeername() .. ":" .. data .. "\n") end
  tcp:send(data .. "\n")
  end

-- send a whole binary file over the network
function tcpsendBinary( file )

  if not projector then return end -- no projector connected yet !

  -- alert the projector that we are about to send a binary file
  tcpsend( projector, "BNRY")

  -- wait for the projector to open a dedicated channel
  local c = tcpbin:accept() 

  file:open('r')
  --local lowlimit = 100 
  --local timerlimit = 50 
  --local timerAbsoluteLimit = 100
  	--repeat

	-- we send a given number of chunks in a row.
	-- At the end of file, we might send a smaller one, then nothing...
  	local data, size = file:read( chunksize )
   	--local i = 1
	--local sizeSent = 0

    	while size ~= 0 do
        	c:send(data) -- send chunk
		--sizeSent = size
		if debug then io.write("sending " .. size .. " bytes. \n") end
		--i = i + 1
		--if i == chunkrepeat then break end
            	data, size = file:read( chunksize )
	end

	--[[
	-- ... then, if something was actually sent, we wait some time
	-- for an acknowledge
	local timer = 0
	local answer = nil
   	if sizeSent ~= 0 then 
		io.write("waiting ................... " .. timerlimit .. " cycles\n")
		while true do
            		socket.sleep(0.05)
			answer, msg = projector:receive()
			timer = timer + 1
			if answer == 'OK' then 
			 	io.write("OK in " .. timer .. " cycles\n") 
				break 
			end
			if timer > timerlimit then break end
		 end
		 if timer > timerlimit then 
			 io.write("warning: did not receive OK within " .. timerlimit .. " cycles. Adjusting timer\n") 
			 timerlimit = timerlimit * 2
			 if timerlimit > timerAbsoluteLimit then timerlimit = timerAbsoluteLimit end
		 else
		   	 timerlimit = math.max( lowlimit, math.ceil(( timerlimit - timer ) / 1.5 ) + 1 )
		 end
	end
	--]]
  	--until sizeSent == 0

  file:close()
  c:close()

  -- send a EOF agreed sequence: Binary EOF
  tcpsend(projector,"BEOF")

  end

-- send dialog message to player
function doDialog( text )
  local _,_,playername,rest = string.find(text,"(%a+)%A?(.*)")
  io.write("send message '" .. text .. "': player=" .. tostring(playername) .. ", text=" .. tostring(rest) .. "\n")
  local tcp = findClientByName( playername )
  if not tcp then io.write("player not found or not connected\n") return end
  tcpsend( tcp, rest ) 
  table.insert( dialogLog , "MJ: " .. string.upper(text) .. "(" .. os.date("%X") .. ")" )
  end

-- capture text input (for text search)
function love.textinput(t)
	if (not searchActive) and (not dialogActive) then return end
	if ignoreLastChar then ignoreLastChar = false; return end
	if searchActive then
		text = text .. t
	else
		dialog = dialog .. t
	end
	end

-- perform a search in the scenario text on one or several
-- words, and return an iterator on the results (or nil 
-- if no results)
-- each call to the iterator returns 
--   x, y coordinates in the image
--   p the pertinence value of the result
--   i the rank in the result list
--   s the total number of results
-- sorted by descending pertinence
function doSearch( sentence )

	local searchResults = {} -- will be part of the iterator

	-- intermediate iresult is an array indexed with couple {"(((x,y))",level}, 
	-- and value a pertinence integer value p depending on the number of occurences
	-- at this position and level
	local iresult = {} 	
	for word in string.gmatch( sentence , "%a+" ) do
		word = string.lower( word )
    		if dictionnary[word] then
	  		for k,v in pairs(dictionnary[word]) do
				if iresult[ v ] then iresult[ v ] = iresult[ v ] + 1 else iresult[ v ] = 1 end
	  		end
		end
	end

	-- inverse this table
	-- result array is now indexed by pertinence, each entry is an array of {"((x,y))",level} 
	local result = {} 
	for k,v in pairs(iresult) do
  		if result[v] then table.insert( result[v], k ) else result[v] = { k } end 
	end

	-- create flat array of (x,y,pertinence,level) from this
	local sr = {}
	for k,v in pairs(result) do
		for i,j in pairs (v) do 
			local _,_,x,y = string.find( j.p , "(%d+)%s*,%s*(%d+)" )
			table.insert( sr , { x=x , y=y , p=k , l=j.l } ) 
		end
	end

	-- remove x,y duplicates, by calculating a unique pertinence = sum( pertinence / (level+1)) for each,
	for k,v in pairs( sr ) do
		-- check if this position already exists
		local exists = false
		for z,t in pairs( searchResults ) do 
			if t.x == v.x and t.y == v.y then
				t.p = t.p + v.p / ( v.l + 1 )	
				exists = true
				break
			end
		end
		if not exists then
			table.insert( searchResults, { x=v.x, y=v.y, p = v.p / (v.l + 1)} )
		end	
	end

 	-- sort them by decreasing pertinence
	table.sort ( searchResults, function(a,b) return a.p > b.p end )

	-- create and return iterator, or nil if no results
	if not searchResults or table.getn( searchResults ) == 0 then return nil end

	local i = 0
	local iter = function()
	  i = i + 1
	  if i > table.getn( searchResults ) then i = 1 end
	  local u = searchResults[ i ]
	  return u.x, u.y, u.p , i, table.getn( searchResults ) 
	  end

	return iter

	end

--
-- dropping a file over the main window will: 
--
-- if it's not a map:
--  * create a snapshot at bottom right of the screen,
--  * send this same image over the socket to the projector client
--  * if a map was visible, it is now hidden
--
-- if it's a map ("map*.jpg or map*.png"):
--  * load it as a new map
--
function love.filedropped(file)

	  local filename = file:getFilename()
	  local is_a_map = false
	  local is_a_pawn = false
	  local is_local = false

	  -- if filename does not contain the base directory, it is local
	  local i = string.find( filename, baseDirectory )
	  is_local = (i == nil) 
	  io.write("is local : " .. tostring(is_local) .. "\n")

	  local _,_,basefile = string.find( filename, ".*" .. sep .. "(.*)")
	  io.write("basefile: " .. tostring(basefile) .. "\n")

	  -- check if is a map or not 
	  if string.sub(basefile,1,3) == "map" and 
	    (string.sub(basefile,-4) == ".jpg" or string.sub(basefile,-4) == ".png") then
	 	is_a_map = true
	  end

	  -- check if is a pawn or not 
	  if string.sub(basefile,1,4) == "pawn" and 
	    (string.sub(basefile,-4) == ".jpg" or string.sub(basefile,-4) == ".png") then
	 	is_a_pawn = true
	  end

	  io.write("is map?: " .. tostring(is_a_map) .. "\n")
	  io.write("is pawn?: " .. tostring(is_a_pawn) .. "\n")

	  if not is_a_map then -- load image 
  	    assert(file:open('r'))
            local image = file:read()
            file:close()

	    local snap = {}

            local lfn = love.filesystem.newFileData
            local lin = love.image.newImageData
            local lgn = love.graphics.newImage
            success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)
            if success then 

		-- create a snapshot object and store it
  		snap.filename = filename
  		snap.baseFilename = string.gsub(filename,baseDirectory,"")
  		snap.im = img 
		snap.is_local = is_local
		if is_local then snap.file = file end
  		snap.w, snap.h = snap.im:getDimensions() 
  		local f1, f2 = snapshotSize / snap.w , snapshotSize / snap.h
  		snap.snapmag = math.min(f1,f2)
  		snap.selected = false
		if is_a_pawn then 
			table.insert( snapshots[3].s , snap )
		else
			table.insert( snapshots[1].s , snap )
		end

	  	-- set the local image
	  	currentImage = img 
		-- remove the 'visible' flag from maps (eventually)
		atlas:removeVisible()
		if not is_local then
    	  	  -- send the filename (without path) over the socket
		  filename = string.gsub(filename,baseDirectory,"")
		  tcpsend(projector,"OPEN " .. filename)
		  tcpsend(projector,"DISP") 	-- display immediately
		else
		  -- send the file itself... not the same story...
		  tcpsendBinary( file )
		  -- display it
		  tcpsend(projector,"DISP")

		end
	    else
	        io.write("cannot load image file " .. filename .. "\n")
	    end	
	
	  elseif is_a_map then  -- add map to the atlas
	    local m = Map:new()
	    m:load{ file=file } -- no filename, and file object means local 
	    --atlas:addMap( m )  
	    layout:addWindow( m , false )
	    table.insert( snapshots[2].s , m )

	  end

	end

-- for a given PNJ at index i, return true if Attack or Armor button should be clickable
-- false otherwise
function isAttorArm( i )
	if not i then return false end
	if not PNJTable[ i ] then return false end
	-- when a PJ is selected, we do not roll for him but for it's enemy, provided 
	-- there is one and only one
  	if (PNJTable[ i ].PJ) then 
    		local count = 0
    		local oneid = nil
    		for k,v in pairs(PNJTable[i].attackers) do 
      			if v then oneid = k; count = count + 1 end
    		end
    		if (count ~= 1) or (not oneid) then return false end
  	end
	-- if it's a PNJ, return true 
	return true	
end


-- Compute dices to roll when "roll attack" or "roll armor" is pressed
-- Roll is made for the character with current focus, provided it is a PNJ and not a PJ
-- If it is a PJ, the roll is made not for him, but for it's opponent, provided there is
-- one and only one (otherwise, do nothing)
-- Return nothing, but activate the corresponding draw flag and timer so it is used in
-- draw()
function rollAttack( rollType )

  	if not focus then return end -- no one with focus, cannot roll

	local index = focus
  
	-- when a PJ is selected, we do not roll for him but for it's enemy, provided there is only one
  	if (PNJTable[ index ].PJ) then 
    		local count = 0
    		local oneid = nil
    		for k,v in pairs(PNJTable[index].attackers) do 
      			if v then oneid = k; count = count + 1 end
    		end
    		if (count ~= 1) or (not oneid) then return end
    		index = findPNJ(oneid)
		-- index now points to the line we want
  	end
 
	-- set global variable so we know if we must draw white or black dices 
  	diceKind = rollType

	-- how many of them ?
  	local num 
  	if rollType == "attack" then
    		num = PNJTable[ index ].roll:getDamage()
  	elseif rollType == "armor" then
    		num = PNJTable[ index ].armor
  	end

	if num == 0 then return end

	--[[
	-- roll them all and store result
  	Dices = {}
  	for i=1,num do Dices[i] = math.random(1,6) end
	--]]

  	math.randomseed( os.time() )
  
	-- prepare the dice box simulation
  	box:set(10,10,5,20,0.8,2,0.01)

	dice = {}
  	for i=1,num do
   		table.insert(dice,
		{ star=newD6star(1.5):set({math.random(10),math.random(10),math.random(10)}, -- position
					  {-math.random(8,40),-math.random(8,40),-10}, -- velocity
					  {math.random(10),math.random(10),math.random(10)}), -- angular mvmt
    		  die=clone(d6,{material=light.plastic,color={127,70,255,255},text={255,255,255},shadow={20,0,0,190}}) })
  	end

  	for i=1,#dice do box[i]=dice[i].star end
  	for i=#dice+1,40 do box[i]=nil end -- FIXME, hardcoded, ugly...
	box.n = #dice

	-- give go to draw them
  	drawDicesTimer = 0
  	drawDices = true
  	drawDicesResult = false
	lastDiceSum = 0
	diceStableTimer = 0

	end



-- GUI basic functions
function love.update(dt)

	-- decrease timelength of 1st message if any
	if messages[1] then 
	  if messages[1].time < 0 then
		messages[1].offset = messages[1].offset + 1
		if messages[1].offset > 21 then table.remove( messages, 1 ) end
	  else	  
		messages[1].time = messages[1].time - dt 
	end	
	end

	-- listening to anyone calling on our port 
	local tcp = server:accept()
	if tcp then
		-- add it to the client list, we don't know who is it for the moment
		table.insert( clients , { tcp = tcp, id = nil } )
		tcp:settimeout(0)
	end

	-- listen to connected clients 
	for i=1,#clients do

 	 local data, msg = clients[i].tcp:receive()

 	 if data then

	    io.write("receiving command: " .. data .. "\n")

	    local command = string.sub( data , 1, 4 )

	    -- this client is unidentified. This should be a connection request
	    if not clients[i].id then

	      if data == "CONNECT" then 
		io.write("receiving projector call\n")
		addMessage("receiving projector call")
		clients[i].id = projectorId
		projector = clients[i].tcp
	    	tcpsend(projector,"CONN")
	
	      elseif 
		-- scan for the command itself to find the player's name
	       string.lower(command) == "eric" or -- FIXME, hardcoded
	       string.lower(command) == "phil" or
	       string.lower(command) == "bibi" or
	       string.lower(command) == "gui " or
	       string.lower(command) == "gay " then
		addMessage( string.upper(data) , 8 , true ) 
		table.insert( dialogLog , string.upper(data) .. " (" .. os.date("%X") .. ")" )
		local index = findPNJByClass( command )
		--PNJTable[index].ip, PNJTable[index].port = lip, lport -- we store the ip,port for further communications 
		clients[i].id = command
		if ack then
			tcpsend( clients[i].tcp, "(ack. " .. os.date("%X") .. ")" )
		end
	      end

	   else -- identified client
		
	    if clients[i].id ~= projectorId then
		-- this is a player calling us, from a known device. We answer
		addMessage( string.upper(clients[i].id) .. " : " .. string.upper(data) , 8 , true ) 
		table.insert( dialogLog , string.upper(clients[i].id) .. " : " .. string.upper(data) .. " (" .. os.date("%X") .. ")" )
		if ack then	
			tcpsend( clients[i].tcp, "(ack. " .. os.date("%X") .. ")" )
		end

	    else
		-- this is the projector
	      if command == "TARG" then

		local map = atlas:getVisible()
		if map and map.pawns then
		  local str = string.sub(data , 6)
                  local _,_,id1,id2 = string.find( str, "(%a+) (%a+)" )
		  local indexP = findPNJ( id1 )
		  local indexT = findPNJ( id2 )
		  updateTargetByArrow( indexP, indexT )
		else
		  io.write("inconsistent TARG command received while no map or no pawns\n")
		end

	      elseif command == "MPAW" then

		local map = atlas:getVisible()
		if map and map.pawns then
		  local str = string.sub(data , 6)
                  local _,_,id,x,y = string.find( str, "(%a+) (%d+) (%d+)" )
		  for i=1,#map.pawns do 
			if map.pawns[i].id == id then 
				map.pawns[i].x = x; map.pawns[i].y = y; 
				pawnMaxLayer = pawnMaxLayer + 1
				map.pawns[i].layer = pawnMaxLayer
				break; 
			end 
		  end 
		  table.sort( map.pawns, function(a,b) return a.layer < b.layer end )
		else
		  io.write("inconsistent MPAW command received while no map or no pawns\n")
		end
	    end -- end of command TARG/MPAW

	  end -- end of identified client

	  end -- end of identified/unidentified

	 end -- end of data

	end -- end of client loop

	-- change snapshot offset if mouse  at bottom right or left
	local snapMax = #snapshots[currentSnap].s * (snapshotSize + snapshotMargin) - W
	if snapMax < 0 then snapMax = 0 end
	local x,y = love.mouse.getPosition()
	if (x < snapshotMargin * 4 ) and (y > snapshotH) and (y < messagesH) then
	  snapshots[currentSnap].offset = snapshots[currentSnap].offset + snapshotMargin * 2
	  if snapshots[currentSnap].offset > 0 then snapshots[currentSnap].offset = 0  end
	end
	if (x > W - snapshotMargin * 4 ) and (y > snapshotH) and (y < messagesH) then
	  snapshots[currentSnap].offset = snapshots[currentSnap].offset - snapshotMargin * 2
	  if snapshots[currentSnap].offset < -snapMax then snapshots[currentSnap].offset = -snapMax end
	end

	-- change some button behaviour when needed
	nextButton.button.black = not nextFlash 
	if not nextButton.button.black then 
		nextButton.button.timer:tween('color', 0.25, nextButton.button, {color = { 80, 110, 180}}, 'linear') 
	else
		nextButton.button.timer:tween('color', 0.25, nextButton.button, {color = { 20, 20, 20}}, 'linear') 
	end

	if isAttorArm( focus ) then
	  attButton.button.black = false 
	  attButton.button.timer:tween('color', 0.25, attButton.button, {color = { 80, 110, 180}}, 'linear') 
	  armButton.button.black = false 
	  armButton.button.timer:tween('color', 0.25, armButton.button, {color = { 80, 110, 180}}, 'linear') 
	else
	  attButton.button.black = true 
	  attButton.button.timer:tween('color', 0.25, attButton.button, {color = { 20, 20, 20}}, 'linear') 
	  armButton.button.black = true 
	  armButton.button.timer:tween('color', 0.25, armButton.button, {color = { 20, 20, 20}}, 'linear') 
	end

	if thereIsDead then
	  clnButton.button.black = false 
	  clnButton.button.timer:tween('color', 0.25, clnButton.button, {color = { 80, 110, 180}}, 'linear') 
	else
	  clnButton.button.black = true
	  clnButton.button.timer:tween('color', 0.25, clnButton.button, {color = { 20, 20, 20}}, 'linear') 
	end

  	-- store current mouse position in arrow mode
  	if arrowMode then 
		arrowX, arrowY = love.mouse.getPosition() 
	end
  
  	-- draw dices if requested
	-- there are two phases of 1 second each: drawDices (all dices) then drawDicesResult (remove failed ones)
  	if drawDices then

  		box:update(dt)

		local immobile = false   
		for i=1,#box do
  		  	if box[i].velocity:abs() > 0.8 then break end -- at least one alive !
  			immobile = true
			drawDicesResult = true
		end

		if immobile then
  			-- for each die, retrieve the 4 points with positive z coordinate
  			-- there should always be 4 (and exactly 4) such points, unless 
  			-- very unlikely situations for the die (not horizontal...). 
  			-- in that case, there is no simple way to retrieve the face anyway
  			-- so forget it...

			lastDiceSum = diceSum

			diceSum = 0
  			for n=1,#box do
    			  local s = box[n]
			  local index = {0,0,0,0} -- will store 4 indexes in the end
			  local t = 1
			  for i=1,8 do if s[i][3] > 0 then index[t] = i; t = t+1 end end
			  local num = whichFace(index[1],index[2],index[3],index[4]) or 0 -- find face number, or 0 if not possible to decide 
			  if num >= 1 and num <= 4 then diceSum = diceSum + 1 end
  			end 

			if lastDiceSum ~= diceSum then diceStableTimer = 0 end
		end
  
		-- dice are removed after a fixed timelength (30 sec.) or after the result is stable for long enough (6 sec.)
    		drawDicesTimer = drawDicesTimer + dt
		diceStableTimer = diceStableTimer + dt
    		if drawDicesTimer >= 30 or diceStableTimer >= 6 then drawDicesTimer = 0; drawDices = false; drawDicesResult = false; end

  	end

	-- check PNJ-related timers
  	for i=1,PNJnum-1 do

  		-- temporarily change color of DEF (defense) value for each PNJ attacked within the last 3 seconds, 
    		if not PNJTable[i].acceptDefLoss then
      			PNJTable[i].lasthit = PNJTable[i].lasthit + dt
      			if (PNJTable[i].lasthit >= 3) then
        			-- end of timer for this PNJ
        			PNJTable[i].acceptDefLoss = true
        			PNJTable[i].lasthit = 0
      			end
    		end

		-- sort and reprint screen after 3 s. an INIT value has been modified
    		if PNJTable[i].initTimerLaunched then
      			PNJtext[i].init.color = color.red
      			PNJTable[i].lastinit = PNJTable[i].lastinit + dt
      			if (PNJTable[i].lastinit >= 3) then
        			-- end of timing for this PNJ
        			PNJTable[i].initTimerLaunched = false
        			PNJTable[i].lastinit = 0
        			PNJtext[i].init.color = color.darkblue
        			sortAndDisplayPNJ()
      			end
    		end

    		if (PNJTable[i].acceptDefLoss) then PNJtext[i].def.color = color.darkblue else PNJtext[i].def.color = { 240, 10, 10 } end

  	end

  	-- change color of "Round" value after a certain amount of time (5 s.)
  	if (newRound) then
    		roundTimer = roundTimer + dt
    		if (roundTimer >= 5) then
      			view.s.t.round.color = color.black
      			view.s.t.round.text = tostring(roundNumber)
      			newRound = false
      			roundTimer = 0
    		end
  	end

  	-- the "next round zone" is blinking (with frequency 400 ms) until "Next Round" is pressed
  	if (nextFlash) then
    		flashTimer = flashTimer + dt
    		if (flashTimer >= 0.4) then
      			flashSequence = not flashSequence
      			flashTimer = 0
    		end
  	else
    		-- reset flash, someone has pressed the button
    		flashSequence = 0
    		flashTimer = 0
  	end

  	view:update(dt)
  	yui.update({view})

	end


-- draw a small colored circle, at position x,y, with 'id' as text
function drawRound( x, y, kind, id )
	if kind == "target" then love.graphics.setColor(250,80,80,180) end
  	if kind == "attacker" then love.graphics.setColor(204,102,0,180) end
  	if kind == "danger" then love.graphics.setColor(66,66,238,180) end 
  	love.graphics.circle ( "fill", x , y , 15 ) 
  	love.graphics.setColor(0,0,0)
  	love.graphics.setFont(fontRound)
  	love.graphics.print ( id, x - string.len(id)*3 , y - 9 )
	end


function myStencilFunction( )
	--local map = atlas:getMap()
	--if not map then return end
	local map = currentWindowDraw
	local x,y,mag,w,h = map.x, map.y, map.mag, map.w, map.h
        local zx,zy = -( x * 1/mag - W / 2), -( y * 1/mag - H / 2)
	love.graphics.rectangle("fill",zx,zy,w/mag,h/mag)
	for k,v in pairs(map.mask) do
		--local _,_,shape,x,y,wm,hm = string.find( v , "(%a+) (%d+) (%d+) (%d+) (%d+)" )
		local _,_,shape = string.find( v , "(%a+)" )
		if shape == "RECT" then 
			local _,_,_,x,y,wm,hm = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+) (%d+)" )
			x = zx + x/mag
			y = zy + y/mag
			love.graphics.rectangle( "fill", x, y, wm/mag, hm/mag) 
		elseif shape == "CIRC" then
			local _,_,_,x,y,r = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+%.?%d+)" )
		  	x = zx + x/mag
			y = zy + y/mag
			love.graphics.circle( "fill", x, y, r/mag ) 
		end
	end
	end

function love.draw() 

  local alpha = 80

  -- bottom snapshots list
  love.graphics.setColor(255,255,255)
  for i=snapshots[currentSnap].index, #snapshots[currentSnap].s do
	local x = snapshots[currentSnap].offset + (snapshotSize + snapshotMargin) * (i-1) - (snapshots[currentSnap].s[i].w * snapshots[currentSnap].s[i].snapmag - snapshotSize) / 2
	if x > W then break end
	if x >= -snapshotSize then 
		if snapshots[currentSnap].s[i].selected then
  			love.graphics.setColor(unpack(color.red))
			love.graphics.rectangle("line", 
				snapshots[currentSnap].offset + (snapshotSize + snapshotMargin) * (i-1),
				snapshotH, 
				snapshotSize, 
				snapshotSize)
  			love.graphics.setColor(255,255,255)
		end
		love.graphics.draw( 	snapshots[currentSnap].s[i].im , 
				x,
				snapshotH - ( snapshots[currentSnap].s[i].h * snapshots[currentSnap].s[i].snapmag - snapshotSize ) / 2, 
			    	0 , snapshots[currentSnap].s[i].snapmag, snapshots[currentSnap].s[i].snapmag )
	end
  end

  -- small snapshot
  love.graphics.setColor(230,230,230)
  love.graphics.rectangle("line", W - W1 - 10, H - H1 - snapshotSize - snapshotMargin * 6 , W1 , H1 )
  if currentImage then 
    local w, h = currentImage:getDimensions()
    -- compute magnifying factor f to fit to screen, with max = 2
    local xfactor = W1 / w
    local yfactor = H1 / h
    local f = math.min( xfactor, yfactor )
    if f > 2 then f = 2 end
    w , h = f * w , f * h
    love.graphics.draw( currentImage , W - W1 - 10 +  (W1 - w) / 2, H - H1 - snapshotSize - snapshotMargin * 6 + ( H1 - h ) / 2, 0 , f, f )
  end

    love.graphics.setLineWidth(3)

    -- draw FOCUS if applicable
    love.graphics.setColor(0,102,0,alpha)
    if focus then love.graphics.rectangle("fill",PNJtext[focus].x+2,PNJtext[focus].y-5,W-12,42) end

    -- draw ATTACKERS if applicable
    love.graphics.setColor(174,102,0,alpha)
    if focusAttackers then
      for i,v in pairs(focusAttackers) do
        if v then
          local index = findPNJ(i)
          if index then 
		  love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,W-12,42) 
		  -- emphasize defense value, but only for PNJ
    		  if not PNJTable[index].PJ then
			  love.graphics.setColor(255,0,0,200)
		  	  love.graphics.rectangle("fill",PNJtext[index].x+743,PNJtext[index].y-3, 26,39) 
		  end
		  PNJtext[index].def.color = { unpack(color.white) }
    		  love.graphics.setColor(204,102,0,alpha)
	  end
        end
      end
    end 

    -- draw TARGET if applicable
    love.graphics.setColor(250,60,60,alpha*1.5)
    local index = findPNJ(focusTarget)
    if index then love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,W-12,42) end

  if nextFlash then
    -- draw a blinking rectangle until Next button is pressed
    if flashSequence then
      love.graphics.setColor(250,80,80,alpha*1.5)
    else
      love.graphics.setColor(0,0,0,alpha*1.5)
    end
    love.graphics.rectangle("fill",PNJtext[1].x+1010,PNJtext[1].y-5,400,(PNJnum-1)*43)
  end

  -- draw view itself
  view:draw()

   
  -- display global dangerosity
  local danger = computeGlobalDangerosity( )
  if danger ~= -1 then drawRound( 1315 , 70, "danger", tostring(danger) ) end
   
  for i = 1, PNJnum-1 do
  
    local offset = 1212
    
    -- display TARGET (in a colored circle) when applicable
    local index = findPNJ(PNJTable[i].target)
    if index then 
        local id = PNJTable[i].target
        if PNJTable[index].PJ then id = PNJTable[index].class end
        drawRound( PNJtext[i].x + offset, PNJtext[i].y + 15, "target", id )
    end
    
    offset = offset + 30 -- in any case

    -- display ATTACKERS (in a colored circle) when applicable
    if PNJTable[i].attackers then
      local sorted = {}
      for id, v in pairs(PNJTable[i].attackers) do if v then table.insert(sorted,id) end end
      table.sort(sorted)
      for k,id in pairs(sorted) do
          local index = findPNJ(id)
          if index and PNJTable[index].PJ then id = PNJTable[index].class end
          if index then drawRound( PNJtext[i].x + offset, PNJtext[i].y + 15, "attacker", id ) ; offset = offset + 30; end
      end
    end
    
    -- display dangerosity per PNJ
    if PNJTable[i].PJ then
      local danger = computeDangerosity( i )
      if danger ~= -1 then drawRound( PNJtext[i].x + offset, PNJtext[i].y + 15, "danger", tostring(danger) ) end
    end
    
    -- draw SNAPSHOT if applicable
    if PNJTable[i].snapshot then
       	    love.graphics.setColor(255,255,255)
	    local s = PNJTable[i].snapshot
	    love.graphics.draw( s.im , 200 , PNJtext[i].y , 0 , s.snapmag * 0.5, s.snapmag * 0.5 ) 
    end

  end

  -- draw windows
  layout:draw() 

 --[[
   local map = atlas:getMap()

   if map then

     local SX,SY,MAG = map.x, map.y, map.mag
     local x,y = -( SX * 1/MAG - W / 2), -( SY * 1/MAG - H / 2)

     if map.mask then	
       love.graphics.setColor(100,100,50,200)
       love.graphics.stencil( myStencilFunction, "increment" )
       love.graphics.setStencilTest("equal", 1)
     else
       love.graphics.setColor(255,255,255,240)
     end

     love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )

     if map.mask then
       love.graphics.setStencilTest("gequal", 2)
       love.graphics.setColor(255,255,255)
       love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )
       love.graphics.setStencilTest()
     end

     -- draw small circle or rectangle in upper corner, to show which mode we are in
     if map.kind == "map" then
       love.graphics.setColor(200,0,0,180)
       if maskType == "RECT" then love.graphics.rectangle("line",x + 5, y + 5,20,20) end
       if maskType == "CIRC" then love.graphics.circle("line",x + 15, y + 15,10) end
     end

     -- draw pawns, if any
     if map.pawns then
	     for i=1,#map.pawns do
       	     	     local index = findPNJ(map.pawns[i].id) 
		     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn 
		     -- is dead, or, worse, has been removed completely from the list
		     if index then 
		     	local dead = false
		     	dead = PNJTable[ index ].is_dead
		     	if map.pawns[i].im then
  		       		local zx,zy = (map.pawns[i].x) * 1/map.mag + x , (map.pawns[i].y) * 1/map.mag + y
		       		if PNJTable[index].PJ then love.graphics.setColor(50,50,250) else love.graphics.setColor(250,50,50) end
		       		love.graphics.rectangle( "fill", zx, zy, (map.pawns[i].size+6) / map.mag, (map.pawns[i].size+6) / map.mag)
		       		if dead then love.graphics.setColor(50,50,50,200) else love.graphics.setColor(255,255,255) end
		       		zx = zx + map.pawns[i].offsetx / map.mag
		       		zy = zy + map.pawns[i].offsety / map.mag
		       		love.graphics.draw( map.pawns[i].im , zx, zy, 0, map.pawns[i].f / map.mag , map.pawns[i].f / map.mag )
	     	     	end
		     end
	     end
     end

     -- print visible 
     if atlas:isVisible( map ) then
        love.graphics.setColor(200,0,0,180)
        love.graphics.setFont(fontDice)
	love.graphics.printf("V", x + map.w / map.mag - 65 , y + 5 ,500)
     end

     -- print search zone for a scenario
     if map.kind == "scenario" then

      love.graphics.setColor(0,0,0)
      love.graphics.setFont(fontSearch)
      love.graphics.printf(text, 800, H - 60, 400)

      -- activate search input zone if needed
      if not searchActive then searchActive = true; dialogActive = false end

      -- print number of the search result is needed
      if searchIterator then love.graphics.printf( "( " .. searchIndex .. " [" .. string.format("%.2f", searchPertinence) .. "] out of " .. 
						           searchSize .. " )", 800, H - 40, 400) end


   end

  end
--]]
  if arrowMode then

      -- draw arrow and arrow head
      love.graphics.setColor(unpack(color.red))
      love.graphics.line( arrowStartX, arrowStartY, arrowX, arrowY )
      local x3, y3, x4, y4 = computeTriangle( arrowStartX, arrowStartY, arrowX, arrowY)
      if x3 then
        love.graphics.polygon( "fill", arrowX, arrowY, x3, y3, x4, y4 )
      end
     
      -- draw circle or rectangle itself
      if arrowModeMap == "RECT" then 
		love.graphics.rectangle("line",arrowStartX, arrowStartY,(arrowX - arrowStartX),(arrowY - arrowStartY)) 
      elseif arrowModeMap == "CIRC" then 
		love.graphics.circle("line",(arrowStartX+arrowX)/2, (arrowStartY+arrowY)/2, distanceFrom(arrowX,arrowY,arrowStartX,arrowStartY) / 2) 
      end
 
 end  

 -- print messages zone in any case 
 love.graphics.setColor(255,255,255)
 love.graphics.rectangle( "fill", 0, messagesH, W, 22 )

 -- print messages eventually
 if messages[1] then
        if messages[1].important then 
		love.graphics.setColor(255,0,0)
	else
		love.graphics.setColor(10,60,220)
	end
        love.graphics.setFont(fontRound)
	love.graphics.setScissor( 0, messagesH, W, 22 )
	love.graphics.printf( messages[1].text, 10 , messagesH - messages[1].offset ,W)
	love.graphics.setScissor()
 end

 -- print dialog zone eventually
 if dialogActive then
      love.graphics.setColor(10,60,220)
      love.graphics.setFont(fontRound)
      love.graphics.printf(dialog, 800, messagesH, W-800)
 end

 -- print dialogLog eventually
 --[[
 if displayDialogLog then
   love.graphics.setFont(fontSearch)
   love.graphics.setColor(10,10,10,150)
   love.graphics.rectangle( "fill", W - 600 , H - 300 , 590 , 250 )  
   local start
   if #dialogLog > 12 then start = #dialogLog - 12 else start = 1 end
   love.graphics.setColor(255,255,255)
   for i=start,#dialogLog do 
	love.graphics.printf( dialogLog[i] , W - 590 , H - 290 + (i-start)*18 , 580 )	
   end
 end
 --]]

  -- draw dices if needed
  if drawDices then

  --use a coordinate system with 0,0 at the center
  --and an approximate width and height of 10
  local cx,cy=380,380
  local scale=cx/4
  
  love.graphics.push()
  love.graphics.translate(cx,cy)
  love.graphics.scale(scale)
  
  render.clear()

  --render.bulb(render.zbuffer) --light source
  for i=1,#dice do if dice[i] then render.die(render.zbuffer, dice[i].die, dice[i].star) end end
  render.paint()

  love.graphics.pop()
  --love.graphics.dbg()

    -- draw number if needed
    if drawDicesResult then
      love.graphics.setColor(unpack(color.red))
      love.graphics.setFont(fontDice)
      love.graphics.print(diceSum,650,4*viewh/5)
    end

  end 

end


function distanceFrom(x1,y1,x2,y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end

-- compute the "head" of the arrow, given 2 points (x1,y1) the starting point of the arrow,
-- and (x2,y2) the ending point. Return 4 values x3,y3,x4,y4 which are the positions of
-- 2 other points which constitute, with (x2,y2), the head triangle
function computeTriangle( x1, y1, x2, y2 )
  local L1 = distanceFrom(x1,y1,x2,y2)
  local L2 = 30
  if L1 < L2 then return nil end -- too small
  local theta = 15
  local x3 = x2 - (L2/L1)*((x1-x2)*math.cos(theta) + (y1 - y2)*math.sin(theta))
  local y3 = y2 - (L2/L1)*((y1-y2)*math.cos(theta) - (x1 - x2)*math.sin(theta))
  local x4 = x2 - (L2/L1)*((x1-x2)*math.cos(theta) - (y1 - y2)*math.sin(theta))
  local y4 = y2 - (L2/L1)*((y1-y2)*math.cos(theta) + (x1 - x2)*math.sin(theta))
  return x3,y3,x4,y4
  end


-- when mouse is released and an arrow is being draw, check if the ending point
-- is on a given PNJ, and update PNJ accordingly
function love.mousereleased( x, y )   

	-- we were moving the map. We stop now
	if mouseMove then mouseMove = false; return end

	-- we were moving a pawn. we stop now
	if pawnMove then 

		arrowMode = false

		-- check that we are in the map...
		--local map = atlas:getMap()
		local map = layout:getFocus()
		if (not map) or (not map:isInside(x,y)) then pawnMove = nil; return end
	
		-- check if we are just stopping on another pawn
		local target = map:isInsidePawn(x,y)
		if target and target ~= pawnMove then

			-- we have a target
			local indexP = findPNJ( pawnMove.id )
			local indexT = findPNJ( target.id )
			updateTargetByArrow( indexP, indexT )
			
		else

			-- it was just a move, change the pawn position
			-- we consider that the mouse position is at the center of the new image
  			local zx,zy = -( map.x * 1/map.mag - W / 2), -( map.y * 1/map.mag - H / 2)
			pawnMove.x, pawnMove.y = (x - zx) * map.mag - pawnMove.size / 2 , (y - zy) * map.mag - pawnMove.size / 2
			pawnMaxLayer = pawnMaxLayer + 1
			pawnMove.layer = pawnMaxLayer
			table.sort( map.pawns , function (a,b) return a.layer < b.layer end )
	
			-- we must stay within the limits of the map	
			if pawnMove.x < 0 then pawnMove.x = 0 end
			if pawnMove.y < 0 then pawnMove.y = 0 end
			if pawnMove.x + pawnMove.size + 6 > map.w then pawnMove.x = math.floor(map.w - pawnMove.size - 6) end
			if pawnMove.y + pawnMove.size + 6 > map.h then pawnMove.y = math.floor(map.h - pawnMove.size - 6) end
	
			tcpsend( projector, "MPAW " .. pawnMove.id .. " " ..  math.floor(pawnMove.x) .. " " .. math.floor(pawnMove.y) )		
			
		end
		pawnMove = nil; 
		return 
	end

	-- we were not drawing anything, nothing to do
  	if not arrowMode then return end

	-- from here, we know that we were drawing an arrow, we stop it now
  	arrowMode = false

	-- if we were drawing a pawn, we stop it now
	if arrowPawn then
		-- this gives the required size for the pawns
  	  	--local map = atlas:getMap()
		local map = layout:getFocus()
		local w = distanceFrom(arrowX,arrowY,arrowStartX,arrowStartY)
		createPawns( map, arrowX, arrowY, w )
		table.sort( map.pawns, function(a,b) return a.layer < b.layer end )
		arrowPawn = false
		return
	end

	-- if we were drawing a mask shape as well, we terminate it now (even if we are outside the map)
	if arrowModeMap then
	
  	  	--local map = atlas:getMap()
		local map = layout:getFocus()
		assert( map and map.class == "map" )

	  	local command = nil

	  	--if arrowX < margin or arrowX > W or arrowY < margin or arrowY > H then return end

	  	if arrowModeMap == "RECT" then

	  		if arrowStartX > arrowX then arrowStartX, arrowX = arrowX, arrowStartX end
	  		if arrowStartY > arrowY then arrowStartY, arrowY = arrowY, arrowStartY end
	  		local sx = math.floor( (arrowStartX + ( map.x / map.mag  - W / 2)) *map.mag )
	  		local sy = math.floor( (arrowStartY + ( map.y / map.mag  - H / 2)) *map.mag )
	  		local w = math.floor((arrowX - arrowStartX) * map.mag)
	  		local h = math.floor((arrowY - arrowStartY) * map.mag)
	  		command = "RECT " .. sx .. " " .. sy .. " " .. w .. " " .. h 

	  	elseif arrowModeMap == "CIRC" then

			local sx, sy = math.floor((arrowX + arrowStartX) / 2), math.floor((arrowY + arrowStartY) / 2)
	  		sx = math.floor( (sx + ( map.x / map.mag  - W / 2)) *map.mag )
	  		sy = math.floor( (sy + ( map.y / map.mag  - H / 2)) *map.mag )
			local r = distanceFrom( arrowX, arrowY, arrowStartX, arrowStartY) * map.mag / 2
	  		if r ~= 0 then command = "CIRC " .. sx .. " " .. sy .. " " .. r end

	  	end

	  	if command then 
			table.insert( map.mask , command ) 
			io.write("inserting new mask " .. command .. "\n")
	  		-- send over if requested
	  		if atlas:isVisible( map ) then tcpsend( projector, command ) end
	  	end

		arrowModeMap = nil
	
	-- not drawing a mask, so maybe selecting a PNJ
	else 
	   	-- depending on position on y-axis
  	  	for i=1,PNJnum-1 do
    		  if (y >= PNJtext[i].y-5 and y < PNJtext[i].y + 42) then
      			-- this stops the arrow mode
      			arrowMode = false
			arrowModeMap = nil
      			arrowStopIndex = i
      			-- set new target
      			if arrowStartIndex ~= arrowStopIndex then 
        			updateTargetByArrow(arrowStartIndex, arrowStopIndex) 
      			end
    		  end
		end	

	end

	end
	
-- put FOCUS on a PNJ line when mouse is pressed (or remove FOCUS if outside PNJ list)
function love.mousepressed( x, y , button )   

	local window = layout:click(x,y)

	if window and window.class == "dialog" then
		-- want to move window 
	   	mouseMove = true
	   	arrowMode = false
	   	arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
		return
	end

	--local map = atlas:getMap()
	-- clicking somewhere in the map, this starts either a Move or a Mask	
	--if map and map:isInside(x,y) then 
	if window and window.class == "map" then

		local map = window

		local p = map:isInsidePawn(x,y)

		if p then

		  -- clicking on a pawn will start an arrow that will represent
		  -- * either an attack, if the arrow ends on another pawn
		  -- * or a move, if the arrow ends somewhere else on the map
		  pawnMove = p
	   	  arrowMode = true
	   	  arrowStartX, arrowStartY = x, y
	   	  mouseMove = false 
		  arrowModeMap = nil 

		-- not clicking a pawn, it's either a map move or an rect/circle mask...
		elseif button == 1 then --Left click
	  		if not love.keyboard.isDown("lshift") and not love.keyboard.isDown("lctrl") then 
				-- want to move map
	   			mouseMove = true
	   			arrowMode = false
	   			arrowStartX, arrowStartY = x, y
				arrowModeMap = nil

          		elseif love.keyboard.isDown("lctrl") then
				-- want to create pawn 
				arrowPawn = true
	   			arrowMode = true
	   			arrowStartX, arrowStartY = x, y
	   			mouseMove = false 
				arrowModeMap = nil 

			else
	   			if map.kind ~= "scenario" then 
					-- want to create a mask
	   				arrowMode = true
					arrowModeMap = maskType 
	   				mouseMove = false 
	   				arrowStartX, arrowStartY = x, y
          			end
        		end


        	end

		return

    	end

  -- Clicking on upper button section does not change the current FOCUS, but cancel the arrow
  if y < 40 then 
    arrowMode = false
    return
  end
 
  -- Clicking on bottom section may select a snapshot image
  if y > H - snapshotSize - snapshotMargin * 2 then
    -- incidentally, this cancels the arrow as well
    arrowMode = false
    -- check if there is a snapshot there
    local index = math.floor((x - snapshots[currentSnap].offset) / ( snapshotSize + snapshotMargin)) + 1
    -- 2 possibilities: if this image is already selected, then use it
    -- otherwise, just select it (and deselect any other eventually)
    if index >= 1 and index <= #snapshots[currentSnap].s then
      if snapshots[currentSnap].s[index].selected then
	      -- already selected
	      snapshots[currentSnap].s[index].selected = false 

	      -- 3 different ways to use a snapshot

	      -- 1: general image, sent it to projector
	      if currentSnap == 1 then
	      	currentImage = snapshots[currentSnap].s[index].im
	      	-- remove the 'visible' flag from maps (eventually)
	      	atlas:removeVisible()
    	      	-- send the filename over the socket
		if snapshots[currentSnap].s[index].is_local then
			tcpsendBinary( snapshots[currentSnap].s[index].file )
		else
	      		tcpsend( projector, "OPEN " .. snapshots[currentSnap].s[index].baseFilename)
		end
	      	tcpsend( projector, "DISP") 	-- display immediately

	      -- 2: map. This should open a window 
	      elseif currentSnap == 2 then

			layout:setDisplay( snapshots[currentSnap].s[index] , true )
	
	      -- 3: Pawn. If focus is set, use this image as PJ/PNJ pawn image 
	      else
			if focus then PNJTable[ focus ].snapshot = snapshots[currentSnap].s[index] end

	      end

      else
	      -- not selected, select it now
	    for i,v in ipairs(snapshots[currentSnap].s) do
	      if i == index then snapshots[currentSnap].s[i].selected = true
	      else snapshots[currentSnap].s[i].selected = false end
	    end

	    -- If in pawn mode, this does NOT change the focus, so we break now !
	    if currentSnap == 3 then return end
      end
    end
  end

  -- we assume that the mouse was pressed outside PNJ list, this might change below
  lastFocus = focus
  focus = nil
  focusTarget = nil
  focusAttackers = nil

  -- check which PNJ was selected, depending on position on y-axis
  for i=1,PNJnum-1 do
    if (y >= PNJtext[i].y-5 and y < PNJtext[i].y + 42) then
      PNJTable[i].focus = true
      lastFocus = focus
      focus = i
      focusTarget = PNJTable[i].target
      focusAttackers = PNJTable[i].attackers
      -- this starts the arrow mode if PNJ
      --if not PNJTable[i].PJ then
        arrowMode = true
        arrowStartX = x
        arrowStartY = y
        arrowStartIndex = i
      --end
    else
      PNJTable[i].focus = false
    end
  end

end


--[[ 
  Pawn object 
--]]
Pawn = {}
Pawn.__index = Pawn
function Pawn.new( id, img, imageFilename, size, x, y ) 
  local new = {}
  setmetatable(new,Pawn)
  new.id = id
  new.layer = pawnMaxLayer 
  new.x, new.y = x or 0, y or 0 	-- relative to the map
  new.filename = imageFilename
  new.baseFilename = string.gsub(imageFilename,baseDirectory,"")
  new.im = img 
  new.size = size 			-- size of the image in pixels, for map at scale 1
  new.f = 1.0
  new.offsetx, new.offsety = 0,0 	-- offset in pixels to center image, within the square, at scale 1
  new.PJ = false
  return new
  end

--
-- Create characters in PNJTable as pawns on the map, with the required (square) size (in pixels, 
-- for map at scale 1), and around the position sx,sy (expressed as pixel position in the screen)
--
-- If createPawns() is called another time, it will only create new characters since last call.
-- In that case, requiredSize is not necessary and ignored, replaced by the current value for
-- other pawns of the map.
--
function createPawns( map , sx, sy, requiredSize ) 
  assert(map)

  local border = 3 -- size of a colored border, in pixels, at scale 1 (3 pixels on all sides)

  -- get actual size at scale 1. We round it to avoid issue when sending to projector
  local createAgain = map.pawns and #map.pawns > 0
  if createAgain then pawnSize = map.pawns[1].size else
  pawnSize = math.floor((requiredSize) * map.mag - border * 2) end

  margin = math.floor(pawnSize / 10) -- small space between 2 pawns

  -- position of the upper-left corner of the map on screen
  local zx,zy = -( map.x * 1/map.mag - W / 2), -( map.y * 1/map.mag - H / 2)

  -- position of the mouse, relative to the map at scale 1 (and not to the screen)
  sx, sy = ( sx - zx ) * map.mag, ( sy - zy ) * map.mag 

  -- set position of 1st pawn to draw (relative to the map)
  local starta,startb = math.floor(sx - 2 * (pawnSize + border*2 + margin)) , math.floor(sy - 2 * (pawnSize + border*2 + margin)) 

  -- a,b could be outside the map, check for this...
  local aw, bh = (pawnSize + border*2 + margin) * 4, (pawnSize + border*2 + margin) * 4
  if starta < 0 then starta = 0 end
  if starta + aw > map.w then starta = map.w - aw end
  if startb < 0 then startb = 0 end
  if startb + bh > map.h then startb = map.h - bh end

  local a,b = starta, startb

  for i=1,PNJnum-1 do

	 local p
	 local needCreate = true

	 if createAgain then
		 -- check if pawn with same ID exists or not
		 for k=1,#map.pawns do if map.pawns[k].id == PNJTable[i].id then needCreate = false; break; end end
	 end

	 if needCreate then
	  local f
	  if PNJTable[i].snapshot then
		f = PNJTable[i].snapshot.filename 
	  	p = Pawn.new( PNJTable[i].id , PNJTable[i].snapshot.im, f , pawnSize, a , b ) 
		local w,h = PNJTable[i].snapshot.im:getDimensions()
		local f1,f2 = pawnSize/w, pawnSize/h
		p.f = math.min(f1,f2)
		p.offsetx = (pawnSize + border*2 - w * p.f ) / 2
		p.offsety = (pawnSize + border*2 - h * p.f ) / 2
	  else
		assert(defaultPawnSnapshot,"no default image available. You should refrain from using pawns on the map...")
		f = defaultPawnSnapshot.filename
	  	p = Pawn.new( PNJTable[i].id , defaultPawnSnapshot.im, f , pawnSize, a , b ) 
		local w,h = defaultPawnSnapshot.im:getDimensions()
		local f1,f2 = pawnSize/w, pawnSize/h
		p.f = math.min(f1,f2)
		p.offsetx = (pawnSize + border*2 - w * p.f ) / 2
		p.offsety = (pawnSize + border*2 - h * p.f ) / 2
	  end
	  io.write("creating pawn " .. i .. " with id " .. p.id .. "\n")
	  p.PJ = PNJTable[i].PJ
	  map.pawns[#map.pawns+1] = p

	  -- send to projector...
	  local flag
	  if p.PJ then flag = "1" else flag = "0" end
	  f = string.gsub(f,baseDirectory,"")
	  io.write("PAWN " .. p.id .. " " .. a .. " " .. b .. " " .. pawnSize .. " " .. flag .. " " .. f .. "\n")
	  tcpsend( projector, "PAWN " .. p.id .. " " .. a .. " " .. b .. " " .. pawnSize .. " " .. flag .. " " .. f)
	  -- set position for next image: we display pawns on 4x4 line/column around the mouse position
	  if i % 4 == 0 then
		a = starta 
		b = b + pawnSize + border*2 + margin
	  else
		a = a + pawnSize + border*2 + margin	
	  end
  	end

  end
  end

--[[ 
  Map object 
--]]
--[[
Map = {}
Map.__index = Map
function Map.new( kind, imageFilename , file ) 
  local new = {}
  setmetatable(new,Map)
  assert( kind == "map" or kind == "scenario" , "sorry, cannot create a map of such kind" )
  new.kind = kind
  local image
  if file then 
	new.is_local = true 
	new.file = file
        new.file:open('r')
  	image = new.file:read()
  	new.file:close()
  else 
	new.is_local = false 
  	new.file = assert(io.open( imageFilename , "rb" ))
  	image = new.file:read('*a')
  	new.file:close()
  end

  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage

  local img = lgn(lin(lfn(image, 'img', 'file')))
  if not img then io.write("sorry, could not load image at '" .. tostring(imageFilename) .. "'") end  
  
  new.filename = imageFilename
  if not new.is_local then new.baseFilename = string.gsub(imageFilename,baseDirectory,"") end
  new.im = img 
  new.w, new.h = new.im:getDimensions() 
  new.x = new.w / 2
  new.y = new.h / 2
  new.mag = 1.0
  new.step = 50
  if kind == "map" then new.mask = {} else new.mask = nil end
  -- inherit from snapshot as well
  local f1, f2 = snapshotSize / new.w , snapshotSize / new.h
  new.snapmag = math.min(f1,f2)
  new.selected = false
  new.pawns = {} 
  return new
  end
--]]

function loadSnap( imageFilename ) 
  local new = {}
  local file = assert(io.open( imageFilename , "rb" ))
  local image = file:read( "*a" )
  file:close()

  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage

  local img = lgn(lin(lfn(image, 'img', 'file')))
  assert(img, "sorry, could not load image at '" .. imageFilename .. "'")  
  
  new.filename = imageFilename
  new.baseFilename = string.gsub(imageFilename,baseDirectory,"")
  new.im = img 
  new.w, new.h = new.im:getDimensions() 
  local f1, f2 = snapshotSize / new.w , snapshotSize / new.h
  new.snapmag = math.min(f1,f2)
  new.selected = false
  new.is_local = false -- a priori
  new.file = nil
  return new
  end

--[[
-- return true if position x,y on the screen (typically, the mouse), is
-- inside the current map display
function Map:isInside(x,y)
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  return x >= zx and x <= zx + self.w / self.mag and 
  	 y >= zy and y <= zy + self.h / self.mag
end
--]]

-- return a pawn if position x,y on the screen (typically, the mouse), is
-- inside any pawn of the map. If several pawns at same location, return the
-- one with highest layer value
function Map:isInsidePawn(x,y)
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2) -- position of the map on the screen
  if self.pawns then
	local indexWithMaxLayer, maxlayer = 0, 0
	for i=1,#self.pawns do
		local lx,ly = self.pawns[i].x, self.pawns[i].y -- position x,y relative to the map, at scale 1
		local tx,ty = zx + lx / self.mag, zy + ly / self.mag -- position tx,ty relative to the screen
		local size = self.pawns[i].size / self.mag -- size relative to the screen
		if x >= tx and x <= tx + size and y >= ty and y <= ty + size and self.pawns[i].layer > maxlayer then
			maxlayer = self.pawns[i].layer
			indexWithMaxLayer = i
		end
  	end
	if indexWithMaxLayer == 0 then return nil else return self.pawns[ indexWithMaxLayer ] end
  end
end

Atlas = {}
Atlas.__index = Atlas
--[[
function Atlas:addMap(m) 
	if m.kind == "scenario" then 
		for k,v in pairs(self.maps) do if v.kind == "scenario" then error("only 1 scenario allowed") end end
		table.insert(self.maps, 1,  m ) -- scenario always first 
	else
		table.insert(self.maps, m);  
	end
	end 

function Atlas:goDisplay()
	self.display = true
	end

function Atlas:toggleDisplay()
	self.display = not self.display
	end

function Atlas:nextMap() 
	if #self.maps == 0 then return nil end 
	if self.index == 0 then self.index = 1; return nil end
	local map = self.maps[self.index]
	self.index = self.index + 1 
	if self.index > #self.maps then self.index = 0 end
	return map 
	end 

function Atlas:getMap() if not self.display then return nil else return self.maps[ self.index ] end end
--]]

function Atlas:getVisible() return self.visible end 

function Atlas:toggleVisible( map )
	--local map = self.maps[ self.index ]
	if not map then return end
	if map.kind == "scenario" then return end -- a scenario is never displayed to the players
	if self.visible == map then 
		self.visible = nil 
		-- erase snapshot !
		currentImage = nil 
	  	-- send hide command to projector
		tcpsend( projector, "HIDE")
	else    
		self.visible = map 
		-- change snapshot !
		currentImage = map.im
		-- send to projector
		if map.is_local then
		  tcpsendBinary( map.file )
		else 
  		  tcpsend( projector, "OPEN " .. map.baseFilename )
		end
  		-- send mask if applicable
  		if map.mask then
			for k,v in pairs( map.mask ) do
				tcpsend( projector, v )
			end
  		end
  		tcpsend( projector, "MAGN " .. 1/map.mag)
  		tcpsend( projector, "CHXY " .. math.floor(map.x) .. " " .. math.floor(map.y) )
  		tcpsend( projector, "DISP")

	end
	end

function Atlas:removeVisible() self.visible = nil end
function Atlas:isVisible(map) return self.visible == map end

function Atlas.new() 
  local new = {}
  setmetatable(new,Atlas)
  new.maps = {}
  new.visible = nil -- map currently visible (or nil if none)
  --new.index = 0 -- index of the current map with focus in map mode (or 0 if none) 
  --new.display = true -- a priori
  return new
  end

--[[ 
  d20 Roll object 
--]]
Roll = {}
Roll.__index = Roll
function Roll:getRoll() return self.roll; end
function Roll:isSuccess() return self.success; end
function Roll:isPassDefense() return self.passDefense; end
function Roll:getVP() return self.VP; end
function Roll:getDamage() return self.damage; end
function Roll.new(goal,defense,basedmg) 
  
  local new = {}
  setmetatable(new,Roll)
  
  new.goal = goal
  new.defense = defense
  new.basedmg = basedmg
  new.VP        = 0
  new.damage    = 0
  new.success   = false
  new.passDefense = false

  new.roll = math.random(1,20)
  
  -- 20 always a failure (or fumble)
  if (new.roll == 20) then 
    new.success = false;
    return new;
  end
  
  -- must roll below the goal, but 1 is always a sucess so we let it pass the test
  if (new.roll > goal and new.roll ~= 1) then 
    new.success = false;
    return new;
  end

  -- base success (we determine PV without taking into account the defense of the target)
  new.VP = math.ceil((new.roll-1)/2)

  -- is it a critical roll?
  if (new.roll == goal) then 
    local newRoll = Roll.new( goal, defense, basedmg )
    if newRoll:isSuccess() then new.VP = new.VP + newRoll:getVP() end
  end

  local success = new.VP

  if defense then
    -- we know the target's defense (not always the case)
    -- reduce PV accordingly
    success = success - defense

    -- sometimes does not pass the defense...
    if success < 0 then 
      new.success = true
      new.passDefense = false 
    else
      new.success = true
      new.passDefense = true
      new.damage = success + basedmg
    end
    
  else -- don't know who is the target...

      new.success = true
      new.passDefense = false -- we don't know
    
  end
  
  return new
  
end
  
function Roll:getVPText()
  if self.roll == 20 then return "(F.)" end
  if not self.success then return "( X )" end
  return "(" .. self.VP .. " VP)" 
  end

function Roll:getDamageText()
  if not self.success then return "( X )" end
  if self.defense then
    if not self.passDefense then return "( X )" end
    return "(".. self.damage .. " D)" 
  else
    return "( ? )"
  end
  end

function Roll:changeDefense( newDefense )
  
  if not self.success then return end -- was not a success anyway, do nothing...
  
  self.defense = newDefense
  
  if not newDefense then
    -- VP does not change
    self.passDefense = false
    self.damage = 0
  else
    local success = self.VP
    success = success - newDefense
    if success < 0 then
      self.passDefense = false
      self.damage = 0
    else
      self.passDefense = true
      self.damage = self.basedmg + success
    end
    
  end
end

-- return a new PNJ object, based on a given template. 
-- Give him a new unique ID 
function PNJConstructor( template ) 

  aNewPNJ = {}

  aNewPNJ.id 		  = generateUID() 		-- unique id
  aNewPNJ.PJ 		  = template.PJ or false	-- is it a PJ or PNJ ?
  aNewPNJ.done		  = false 			-- has played this round ?
  aNewPNJ.is_dead         = false  			-- so far 
  aNewPNJ.snapshot	  = nil				-- image (and some other information) for the PJ

  aNewPNJ.ip	  	  = nil				-- for PJ only: ip, if the player is using udp remote communication 
  aNewPNJ.port	  	  = nil				-- for PJ only: port, if the player is using udp remote communication 

  -- GRAPHICAL INTERFACE (focus, timers...)
  aNewPNJ.focus	  	  = false			-- has the focus currently ?

  aNewPNJ.lasthit	  = 0			        -- time when last attacked or lost hit points. This starts a timer of 3 seconds during which
							-- the character cannot loose DEFense value again
  aNewPNJ.acceptDefLoss   = true			-- linked to the timer above: In general a character should accept to loose DEFense
							-- at anytime (acceptDefLoss = true), except that each time DEF is lost, we must wait 3 seconds
							-- before another DEF point can be lost again (and during that time, acceptDefLoss = false) 

  aNewPNJ.initTimerLaunched = false
  aNewPNJ.lastinit	  = 0				-- time when initiative last changed. This starts a timer before the PNJ list is sorted and 
							-- printed to screen again

  -- BASE CHARACTERISTICS
  aNewPNJ.class	      	= template.class or ""
  aNewPNJ.intelligence 	= template.intelligence or 3
  aNewPNJ.perception   	= template.perception or 3
  aNewPNJ.endurance    	= template.endurance or 5    
  aNewPNJ.force        	= template.force or 5        
  aNewPNJ.dex          	= template.dex or 5     	-- Characteristic DEXTERITY

  aNewPNJ.fight        	= template.fight or 5        
  	-- 'fight' is a generic skill that represents all melee/missile capabilities at the same time
  	-- here we avoid managing separate and detailed skills depending on each weapon...

  aNewPNJ.weapon    	= template.weapon or ""
  aNewPNJ.defense      	= template.defense or 1 
  aNewPNJ.dmg          	= template.dmg or 2		-- default damage is 2 (handfight)
  aNewPNJ.armor        	= template.armor or 1      	-- number of dices (eg 1 means 1D armor)

  -- OPPONENTS
  aNewPNJ.target   	= nil 				-- ID of its current target, or nil if not attacking anyone
  aNewPNJ.attackers    	= {}				-- list of IDs of all opponents attacking him 

  -- DERIVED CHARACTERISTICS
  aNewPNJ.initiative    	= aNewPNJ.intelligence + aNewPNJ.dex -- Base initiative. for PNJ, a d6 is added during combat 
  aNewPNJ.final_initiative 	= 0  -- for the moment, will be fixed later

  -- We apply some basic maluses for PNJ (not for PJ for whom we take literal values)
  if not aNewPNJ.PJ then
    -- damage bonus (we apply it without consideration of melee or missile weapon)
    if (aNewPNJ.force >= 9) then aNewPNJ.dmg = aNewPNJ.dmg + 2 elseif (aNewPNJ.force >= 6) then aNewPNJ.dmg = aNewPNJ.dmg + 1 end

    -- maluses due to armor
    -- we apply very simple rules, as follows
    -- Armor >= 2, malus -1 to INIT
    -- Armor >= 3, malus -1 to INIT and DEX
    -- Armor >= 4, malus -3 to INIT, and -1 to DEX and FOR 
    if (aNewPNJ.armor >= 4) then aNewPNJ.initiative = aNewPNJ.initiative -3; aNewPNJ.dex = aNewPNJ.dex - 1; aNewPNJ.force = aNewPNJ.force -1
    elseif (aNewPNJ.armor >= 3) then  aNewPNJ.initiative = aNewPNJ.initiative - 1; aNewPNJ.dex = aNewPNJ.dex - 1 
    elseif (aNewPNJ.armor >= 2) then aNewPNJ.initiative = aNewPNJ.initiative -1;  end
  end

  aNewPNJ.hits        	= aNewPNJ.endurance + aNewPNJ.force + 5
  aNewPNJ.goal         	= aNewPNJ.dex + aNewPNJ.fight
  aNewPNJ.malus	        = 0
	-- generic malus due to low hits (-2 to -10)

  aNewPNJ.defmalus       = 0
	-- malus to defense for the current round, due to attacks
	-- this malus is reinitialized each round

  aNewPNJ.stance         = "neutral" -- by default
  aNewPNJ.defstancemalus = 0
	-- malus to defense due to stance (-2 to +2) 

  aNewPNJ.goalstancebonus= 0
	-- bonus (or malus) to goal due to stance (-3 to +3) 

  aNewPNJ.final_defense = aNewPNJ.defense
  aNewPNJ.final_goal    = aNewPNJ.goal

  -- roll a D20
  aNewPNJ.roll	= Roll.new(
    aNewPNJ.final_goal,   -- current goal
    nil, 		  -- no target yet, so no defense to pass
    aNewPNJ.dmg 	  -- weapon's damage
    )			  -- dice roll for this round

  return aNewPNJ
  
  end 

-- GUI function: set the color for the ith-line ( = ith PNJ)
function updateLineColor( i )

  PNJtext[i].init.color 			= color.darkblue
  PNJtext[i].def.color 				= color.darkblue

  if not PNJTable[i].PJ then
    if not PNJTable[i].roll:isSuccess() then 
      PNJtext[i].roll.color 			= color.red
      PNJtext[i].dmg.color 			= color.red
    elseif not PNJTable[i].roll:isPassDefense() then
      PNJtext[i].roll.color 			= color.orange
      PNJtext[i].dmg.color 			= color.orange
    else 
      PNJtext[i].roll.color 			= color.darkgreen
      PNJtext[i].dmg.color 			= color.darkgreen
    end
  else
    PNJtext[i].roll.color 			= color.purple
    PNJtext[i].dmg.color 			= color.purple
  end

  if (PNJTable[i].done) then
    PNJtext[i].id.color 			= color.masked
    PNJtext[i].class.color 			= color.masked
    PNJtext[i].endfordexfight.color 		= color.masked
    PNJtext[i].weapon.color 			= color.masked
    PNJtext[i].goal.color 			= color.masked
    PNJtext[i].armor.color 			= color.masked
    PNJtext[i].roll.color 			= color.masked
    PNJtext[i].dmg.color 			= color.masked
  elseif PNJTable[i].PJ then
    PNJtext[i].id.color 			= color.purple
    PNJtext[i].class.color 			= color.purple
    PNJtext[i].endfordexfight.color 		= color.purple
    PNJtext[i].weapon.color 			= color.purple
    PNJtext[i].goal.color 			= color.purple
    PNJtext[i].armor.color 			= color.purple
  else
    PNJtext[i].id.color 			= color.black
    PNJtext[i].class.color 			= color.black
    PNJtext[i].endfordexfight.color 		= color.black
    PNJtext[i].weapon.color 			= color.black
    PNJtext[i].goal.color 			= color.black
    PNJtext[i].armor.color 			= color.black
  end
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- return the index of the 1st character of a class, or nil if not found
function findPNJByClass( class )
  if not class then return nil end
  class = string.lower( trim(class) )
  for i=1,PNJnum-1 do if string.lower(PNJTable[i].class) == class then return i end end
  return nil
  end

function findClientByName( class )
  if not class then return nil end
  if not clients then return nil end
  class = string.lower( trim(class) )
  for i=1,#clients do if string.lower(clients[i].id) == class then return i end end
  return nil
  end

-- return the character by its ID, or nil if not found
function findPNJ( id )
  if not id then return nil end
  for i=1,PNJnum-1 do if PNJTable[i].id == id then return i end end
  return nil
  end

-- set the target of i to j (i attacks j)
-- then update roll results accordingly (but does not reroll)
function updateTargetByArrow( i, j )

  -- set new target value
  if PNJTable[i].target == PNJTable[j].id then return end -- no change in target, do nothing
  
  -- set new target
  PNJTable[i].target = PNJTable[j].id
  
  -- remove i as attacker of anybody else
  PNJTable[j].attackers[ PNJTable[i].id ] = true
  for k=1,PNJnum-1 do
    if k ~= j then PNJTable[k].attackers[ PNJTable[i].id ] = false end
  end
  
  -- determine new success & damage
  -- only needed if:
  -- a) the character is a PNJ (we do not roll for PJ)
  -- b) his target was modified actually...
    local defense =  PNJTable[ j ].final_defense
    
    PNJTable[i].roll:changeDefense( defense )
    
    -- display, with proper color	
    PNJtext[i].roll.text 		= PNJTable[i].roll:getRoll()
    PNJtext[i].dmg.text2 		= PNJTable[i].roll:getVPText()
    PNJtext[i].dmg.text3 		= PNJTable[i].roll:getDamageText()

    updateLineColor(i)

    lastFocus = focus
    focus = i
    focusAttackers = PNJTable[i].attackers
    focusTarget = PNJTable[i].target
    
end

function love.mousemoved(x,y,dx,dy)

if mouseMove then

   --local map = atlas:getMap() 
   local map = layout:getFocus()

   if map then

	-- store old values, in case we need to rollback because we get outside limits
	local oldx, oldy = map.x, map.y

	-- apply changes
	map.x = map.x - dx * map.mag 
	map.y = map.y - dy * map.mag 

	-- check we are still within margins of the screen
  	local zx,zy = -( map.x * 1/map.mag - W / 2), -( map.y * 1/map.mag - H / 2)
	
	if zx > W - margin or zx + map.w / map.mag < margin then map.x = oldx end	
	if zy > H - margin or zy + map.h / map.mag < margin then map.y = oldy end	

	-- send move to the projector
	if (map.x ~= oldx or map.y ~= oldy) and atlas:isVisible(map) then tcpsend( projector, "CHXY " .. math.floor(map.x) .. " " .. math.floor(map.y) ) end

    end
end

end

function love.keypressed( key, isrepeat )

-- keys applicable in any context
-- we expect:
-- 'lctrl + d' : open dialog window
if key == "d" and love.keyboard.isDown("lctrl") then
  if dialogWindow then 
	layout:setDisplay( dialogWindow, true )
	layout:setFocus( dialogWindow ) 
  else
	dialogWindow = Dialog:new{w=600,h=300,x=300,y=150}
	layout:addWindow( dialogWindow , true ) -- display it. Set focus
  end
end

-- other keys applicable 
local window = layout:getFocus()
if not window then
  -- no window selected at the moment, we expect:
  -- 'up', 'down' within the PNJ list
  -- 'space' to change snapshot list
  if focus and key == "down" then
    if focus < PNJnum-1 then 
      lastFocus = focus
      focus = focus + 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
  end
  
  if focus and key == "up" then
    if focus > 1 then 
      lastFocus = focus
      focus = focus - 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
    return
  end

  if key == 'space' then
	  currentSnap = currentSnap + 1
	  if currentSnap == 4 then currentSnap = 1 end
  end
  
else
  -- a window is selected. Keys applicable to any window:
  -- 'lctrl + c' : center window
  -- 'lctrl + x' : close window
  if key == "x" and love.keyboard.isDown("lctrl") then
	layout:setDisplay( window, false )
	return
  end
  if key == "c" and love.keyboard.isDown("lctrl") then
	window.x, window.y = window.w / 2, window.h / 2
	return
  end
  if     window.class == "dialog" then
	-- 'return' to submit a dialog message
	-- 'backspace'
	-- any other key is treated as a message input
  	if (key == "return") then
	  doDialog( string.gsub( dialog, dialogBase, "" , 1) )
	  dialog = dialogBase
	  --dialogActive = false 
  	end

  	if (key == "backspace") and (dialog ~= dialogBase) then
         -- get the byte offset to the last UTF-8 character in the string.
         local byteoffset = utf8.offset(dialog, -1)
         if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            dialog = string.sub(dialog, 1, byteoffset - 1)
         end
  	end
	
  elseif window.class == "map" and window.kind == "map" then

	local map = window

	-- keys for map. We expect:
	-- Zoom in and out
	-- 'tab' to get to circ or rect mode
	-- 'lctrl + p' to remove all pawns
	-- 'lctrl + v' : toggle visible / not visible
    	if key == keyZoomIn then
		if map.mag >= 1 then map.mag = map.mag + 1 end
		if map.mag == 0.5 then map.mag = 1 end	
		if map.mag == 0.25 then map.mag = 0.5 end	
		ignoreLastChar = true
		if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    	end 

    	if key == keyZoomOut then
		if map.mag > 1 then map.mag = map.mag - 1 
		elseif map.mag == 1 then map.mag = 0.5 
		elseif map.mag == 0.5 then map.mag = 0.25 end	
		if map.mag == 0 then map.mag = 0.25 end
		ignoreLastChar = true
		if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    	end 
    
	if key == "v" and love.keyboard.isDown("lctrl") then
		atlas:toggleVisible( map )
    	end

   	if key == "p" and love.keyboard.isDown("lctrl") then
	   map.pawns = {} 
	   tcpsend( projector, "ERAS" )    
   	end

   	if key == "tab" then
	  if maskType == "RECT" then maskType = "CIRC" else maskType = "RECT" end
   	end
	
  elseif window.class == "map" and window.kind == "scenario" then

	local map = window

	-- keys for map. We expect:
	-- Zoom in and out
	-- 'return' to submit a query
	-- 'backspace'
	-- 'tab' to get to next search result
	-- any other key is treated as a search query input
    	if key == keyZoomIn then
		if map.mag >= 1 then map.mag = map.mag + 1 end
		if map.mag == 0.5 then map.mag = 1 end	
		if map.mag == 0.25 then map.mag = 0.5 end	
		ignoreLastChar = true
		if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    	end 

    	if key == keyZoomOut then
		if map.mag > 1 then map.mag = map.mag - 1 
		elseif map.mag == 1 then map.mag = 0.5 
		elseif map.mag == 0.5 then map.mag = 0.25 end	
		if map.mag == 0 then map.mag = 0.25 end
		ignoreLastChar = true
		if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    	end 
	
  end
end

--[[
  local map = atlas:getMap()

  -- UP and DOWN change focus to previous/next PNJ
  if focus and key == "down" then
    if focus < PNJnum-1 then 
      lastFocus = focus
      focus = focus + 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
  end
  
  if focus and key == "up" then
    if focus > 1 then 
      lastFocus = focus
      focus = focus - 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
    return
  end

  if key == 'rshift' then
	  currentSnap = currentSnap + 1
	  if currentSnap == 4 then currentSnap = 1 end
  end

  -- "d" open dialog zone
  if (not searchActive) and (not dialogActive) and (key == "d") then
	dialogActive = true 
	ignoreLastChar = true 
  end

  --  "left ctrl + f" open dialog log. same thing to close it 
  if (key == "f") and love.keyboard.isDown("lctrl") then
	displayDialogLog = not displayDialogLog 
	ignoreLastChar = true 
  end

  if dialogActive and (key == "return") then
	  doDialog( string.gsub( dialog, dialogBase, "" , 1) )
	  dialog = dialogBase
	  dialogActive = false 
  end

  if dialogActive and (key == "backspace") and (dialog ~= dialogBase) then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(dialog, -1)
 
        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            dialog = string.sub(dialog, 1, byteoffset - 1)
        end
  end

  -- SPACE moves to next map
  if (not dialogActive) and key == "space" then
	  map = atlas:nextMap()
	  -- reset search input
	  searchActive = false
	  text = textBase
	  if map then	
	    -- if we switch to another map, we display it, whatever the previous display flag
	    atlas:goDisplay()
	  end
  end

  -- ESCAPE hides or restores display of the current map, but does not change it
  if key == "escape" then
	atlas:toggleDisplay()
  end

  --
  -- ALL MAPS
  --
  if map then

    -- ZOOM in and out
    if key == keyZoomIn then
	if map.mag >= 1 then map.mag = map.mag + 1 end
	if map.mag == 0.5 then map.mag = 1 end	
	if map.mag == 0.25 then map.mag = 0.5 end	
	ignoreLastChar = true
	if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    end 

    if key == keyZoomOut then
	if map.mag > 1 then 
		map.mag = map.mag - 1 
	elseif map.mag == 1 then 
		map.mag = 0.5 
	elseif map.mag == 0.5 then
		map.mag = 0.25
	end	
	if map.mag == 0 then map.mag = 0.25 end
	ignoreLastChar = true
	if atlas:isVisible(map) then tcpsend( projector, "MAGN " .. 1/map.mag ) end	
    end 

    -- V for VISIBLE
    if (not dialogActive) and key == "v" and map.kind == "map" then
	atlas:toggleVisible()
    end

    -- C for RECENTER
    if (not dialogActive) and key == "c" then
	map.x = map.w / 2
	map.y = map.h / 2
    end

   -- REMOVE ALL PAWNS
   if (not dialogActive) and key == "x" and love.keyboard.isDown("lctrl") then
	   map.pawns = {} 
	   tcpsend( projector, "ERAS" )    
   end

   -- display PJ snapshots or not
   --if key == "s" and map.kind =="map" then displayPJSnapshots = not displayPJSnapshots end

   -- TAB switches between rectangles and circles
   if key == "tab" then
	  if maskType == "RECT" then maskType = "CIRC" else maskType = "RECT" end
   end

  end

  --
  -- SCENARIO SPECIFIC
  -- 
  if map and map.kind == "scenario" then

   if key == "backspace" and text ~= textBase then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(text, -1)
 
        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            text = string.sub(text, 1, byteoffset - 1)
        end
    end

   if key == "tab" then


	  if searchIterator then
		map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator()
	  end



   end

   if key == "return" then
	  searchIterator = doSearch( string.gsub( text, textBase, "" , 1) )
	  text = textBase
	  if searchIterator then
		map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator()
	  end
   end

   end 
--]]

   end


-- For an opponent (at index k) attacking a PJ (at index i), return
-- an "average touch" value ( a number of hits ) which is an average
-- number of damage points weighted with an average probability to hit
-- in this round
function averageTouch( i, k )
  if PNJTable[k].PJ then return 0 end -- we compute only for PNJ
  local dicemin = PNJTable[i].final_defense*2 - 1
  if dicemin < 0 then dicemin = 0 end
  local dicemax = PNJTable[k].final_goal
  local diceinterval = dicemax - dicemin
  if diceinterval < 0 then diceinterval = 0 end
  local chanceToTouch = diceinterval / 20 
  local damage = PNJTable[k].dmg + (diceinterval / 2)
  return chanceToTouch * (damage - PNJTable[i].armor) * (2/3)
  end

-- the dangerosity, for a PJ at index i, is an average calculation
-- based on its current hits and values of its opponents, which
-- represents an estimated (and averaged) number of rounds before dying.
-- Return the dangerosity value (an integer), or -1 if cannot be computed 
-- (eg. no opponent )
function computeDangerosity( i )
  local potentialTouch = 0
  for k,v in pairs(PNJTable[i].attackers) do
    if v then
      local index = findPNJ( k )
      if index then potentialTouch = potentialTouch + averageTouch( i , index ) end
    end
  end
  if potentialTouch ~= 0 then return math.ceil( PNJTable[i].hits / potentialTouch ) else return -1 end
  end

-- compute dangerosity for the whole group
function computeGlobalDangerosity()
  local potentialTouch = 0
  local hits = 0
  for i=1,PNJnum-1 do
   if PNJTable[i].PJ then
    hits = hits + PNJTable[i].hits
    for k,v in pairs(PNJTable[i].attackers) do
     if v then
      local index = findPNJ( k )
      if index then potentialTouch = potentialTouch + averageTouch( i , index ) end
     end
    end
   end
  end
  if potentialTouch ~= 0 then return math.ceil( hits / potentialTouch ) else return -1 end
  end

-- add n to the current defense malus of the i-th character (n can be positive or negative)
-- set to m the defense stance malus of the i-th character. If m is nil, does not alter the current stance malus
-- This will result in 2 effects:
-- a) alter the current total DEFENSE of the character
-- b) if another character is targeting this one, then modify damage roll result accordingly
function changeDefense( i, n, m )

  -- lower defense
  PNJTable[i].defmalus = PNJTable[i].defmalus + n
  if m then PNJTable[i].defstancemalus = m end
  PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defmalus + PNJTable[i].defstancemalus;
  PNJtext[i].def.text = PNJTable[i].final_defense; 

  -- check for potential attacking characters, who have not played yet in the round   
  for j=1,PNJnum-1 do

    if not PNJTable[j].done then

      if PNJTable[j].target == PNJTable[i].id then

        -- determine new success & damage
        
        PNJTable[j].roll:changeDefense( PNJTable[i].final_defense )
        
        -- display, with proper color	
        PNJtext[j].roll.text 		= PNJTable[j].roll:getRoll()
        PNJtext[j].dmg.text2 		= PNJTable[j].roll:getVPText()
        PNJtext[j].dmg.text3 		= PNJTable[j].roll:getDamageText()

        updateLineColor(j)

      end
    end

  end

end

-- create and return the PNJ list GUI frame 
-- (with blank values at that time)
function createPNJGUIFrame()

  local t = {name="pnjlist"}
  local width = 60;
  t[1] = yui.Flow({ name="headline",
      yui.Text({text="Done", w=40, size=size-2, bold=1, center = 1 }),
      yui.Text({text="ID", w=35, size=size, bold=1, center = 1 }),
      yui.Text({text="CLASS", w=width*2.5, bold=1, size=size, center = 1}),
      yui.Text({text="INIT", w=90, bold=1, size=size, center = 1}),
      yui.Text({text="INT/END/FOR\nDEX/FIGHT/PER", bold=1, w=125, size=size-2, center = 1}),
      yui.Text({text="WEAPON", w=width*2, bold=1, size=size, center = 1 }),
      yui.Text({text="GOAL", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="ROLL", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="DMG", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="DEF", w=75, bold=1, size=size }),
      yui.Text({text="ARM", w=width, bold=1, size=size, center = 1}),
      yui.Text({text="HITS", w=80, bold=1, size=size}),
      yui.HorizontalSpacing({w=30}),
      yui.Text({name="stance", text="STANCE (Agress., Neutre, Def.)", w=220, size=size, center=1}),
      yui.Text({text="OPPONENTS", w=40, bold=1, size=size}),
    }) 

  for i=1,PNJmax do
    t[i+1] = 
    yui.Flow({ name="PNJ"..i,

        yui.HorizontalSpacing({w=10}),
        yui.Checkbox({name = "done", text = '', w = 30, 
            onClick = function(self) 
              if (PNJTable[i]) then 
                PNJTable[i].done = self.checkbox.checked; 
                updateLineColor(i)
                checkForNextRound() 
              end  
            end}),

        yui.Text({name="id",text="", w=35, bold=1, size=size, center = 1 }),
        yui.Text({name="class",text="", w=width*2.5, bold=1, size=size, center=false}),
        yui.Text({name="init",text="", w=40, bold=1, size=size, center = 1, color = color.darkblue}),

        yui.Button({name="initm", text = '-', size=size-4,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              if (PNJTable[i].PJ) then 
                if (PNJTable[i].final_initiative >= 1) then PNJTable[i].final_initiative = PNJTable[i].final_initiative - 1 end
                self.parent.init.text = PNJTable[i].final_initiative
                PNJTable[i].initTimerLaunched = true 
              end
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="initp", text = '+', size=size-4,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              if (PNJTable[i].PJ) then 
                PNJTable[i].final_initiative = PNJTable[i].final_initiative + 1
                self.parent.init.text = PNJTable[i].final_initiative
                PNJTable[i].initTimerLaunched = true 
              end
            end}),

        yui.Text({name="endfordexfight", text = "", bold=1, w=width*2, size=size-4, center = 1}),
        yui.Text({name="weapon",text="", w=width*2, bold=1, size=size, center = 1}),
        yui.Text({name="goal",text="", w=width, bold=1, size=size+4, center = 1}),
        yui.Text({name="roll",text="", w=width-20, bold=1, size=size+4, center=1, color = color.darkblue}),
        yui.Text({name="dmg",text="", text2 = "", text3 = "", w=width+25, bold=1, size=size+4, center = 1}),

        yui.Text({name="def", text="", w=40, bold=1, size=size+4, color = color.darkblue , center = 1}),

        yui.Button({name="minusd", text = '-', size=size,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              changeDefense(i,-1,nil)
            end}),

        yui.Text({name="armor",text="", w=width, bold=1, size=size, center = 1}),
        yui.Text({name="hits", text="", w=40, bold=1, size=size+8, color = color.red, center = 1}),

        yui.Button({name="minus", text = '-1', size=size-2,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].hits = PNJTable[i].hits - 1
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                changeDefense(i,-1,nil)
                PNJTable[i].lasthit = 0
                PNJTable[i].acceptDefLoss = false
              end
              if (PNJTable[i].hits == 0) then 
                PNJTable[i].is_dead = true; 

		tcpsend( projector, "KILL " .. PNJTable[i].id )

                self.parent.done.checkbox.set = true -- a dead character is done
                PNJTable[i].done = true
                self.parent.stance.text = "--"; 
                self.parent.roll.text = "--"; 
                self.parent.hits.text = "--"; 
                self.parent.goal.text = "--"; 
                self.parent.armor.text = "--"; 
                self.parent.dmg.text = "--"; 
                self.parent.weapon.text = "--"; 
                self.parent.endfordexfight.text = "--"; 
                self.parent.def.text = "--"; 
                self.parent.dmg.text2 = "";
                self.parent.dmg.text3 = "";
		thereIsDead = true
                checkForNextRound()
                return
              end

              if (PNJTable[i].hits >0 and PNJTable[i].hits <= 5) then
                PNJTable[i].malus = -12 + (2 * PNJTable[i].hits)
              end
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus
              self.parent.goal.text = PNJTable[i].final_goal
              self.parent.hits.text = PNJTable[i].hits 
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="shot", text = '0', size=size-2,
            onClick = function(self) 
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              -- remove DEF if allowed
              if PNJTable[i].acceptDefLoss then
                changeDefense(i,-1,nil)
                PNJTable[i].lasthit = 0
                PNJTable[i].acceptDefLoss = false
              end
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus
            end}),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="kill", text = 'kill', size=size-2, 
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].hits = 0
              PNJTable[i].is_dead = true 

	      tcpsend( projector, "KILL " .. PNJTable[i].id )

              self.parent.done.checkbox.set = true -- a dead character is done
              PNJTable[i].done = true
              self.parent.stance.text = "--"; 
              self.parent.hits.text = "--"; 
              self.parent.roll.text = "--";
              self.parent.goal.text = "--"; 
              self.parent.armor.text = "--"; 
              self.parent.dmg.text = "--"; 
              self.parent.weapon.text = "--"; 
              self.parent.endfordexfight.text = "--"; 
              self.parent.def.text = "--"; 
              self.parent.dmg.text2 = "";
              self.parent.dmg.text3 = "";
	      thereIsDead = true
              checkForNextRound()
            end }),

        yui.HorizontalSpacing({w=12}),
        yui.Text({name="stance",text="", w=100, size=size, center = 1}),
        yui.Button({name="agressive", text = 'A', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,-2)
              PNJTable[i].stance = "agress."
              self.parent.stance.text = "agress."; 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="neutral", text = 'N', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = 0;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,0)
              PNJTable[i].stance = "neutral"
              self.parent.stance.text = "neutral" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=3}),
        yui.Button({name="defense", text = 'D', size=size,
            onClick = function(self)
              if (i>=PNJnum) then return end
              if (PNJTable[i].is_dead) then return end
              PNJTable[i].goalstancebonus = -3;
              PNJTable[i].final_goal = PNJTable[i].goal + PNJTable[i].malus + PNJTable[i].goalstancebonus;
              changeDefense(i,0,2)
              PNJTable[i].stance = "defense"
              self.parent.stance.text = "defense" 
              self.parent.def.text = PNJTable[i].final_defense; 
              self.parent.goal.text = PNJTable[i].final_goal; 
              -- if PNJ has not played yet, reroll
              if not PNJTable[i].done then reroll(i) end
            end }),

        yui.HorizontalSpacing({w=10})
        
      })
    PNJtext[i] = t[i+1] 
  end 

  return yui.Stack(t)
end

-- return an iterator which generates new unique ID, 
-- from "A", "B" ... thru "Z", then "AA", "AB" etc.
function UIDiterator() 
  local UID = ""
  local incrementAlphaID = function ()
    if UID == "" then UID = "A" return UID end
    local head=UID:sub( 1, UID:len() - 1)
    local tail=UID:byte( UID:len() )
    local id
    if (tail == 90) then 
	local u = UIDiterator()
	id = u(head) .. "A" 
    else 
	id = head .. string.char(tail+1) 
    end
    UID = id
    return UID
    end
  return incrementAlphaID 
  end

-- create and store a new PNJ in PNJTable{}, based on a given class,
-- return true if a new PNJ was actually generated, 
-- false otherwise (because limit is reached).
--
-- If a PNJ with same class was already generated before, then keeps
-- the same INITIATIVE value (so all PNJs with same class are sorted
-- together)
--
-- The newly created PNJ is stored at the end of the PNJTable{} for
-- the moment
function generateNewPNJ(current_class)

  -- cannot generate too many PNJ...
  if (PNJnum > PNJmax) then return false end

  -- generate a new one, at current index, with new ID
  PNJTable[PNJnum] = PNJConstructor( templateArray[current_class] )

  -- display it's class and INIT value (rest will be displayed when start button is pressed)
  local pnj = PNJTable[PNJnum]
  PNJtext[PNJnum].class.text = current_class;

  if (pnj.PJ) then

    pnj.final_initiative = pnj.initiative;
    PNJtext[PNJnum].init.text  = pnj.final_initiative;

  else

    -- set a default image
    pnj.snapshot = defaultPawnSnapshot

    -- check if same class has already been generated before. If so, take same initiative value
    -- otherwise, assign a new value (common to the whole class)
    -- the new value is INITIATIVE + 1D6
    local found = false
    for i=1,PNJnum-1 do
      if (PNJTable[i].class == current_class) then 
        found = true; 
        PNJtext[PNJnum].init.text = PNJtext[i].init.text; 
        pnj.final_initiative = PNJTable[i].final_initiative
      end
    end
    if not found then
      math.randomseed( os.time() )
      -- small trick: we do not add 1d6, but 1d6 plus a fraction between 0-1
      -- and we always remove this fraction (math.floor) when we display the value
      -- In this way, 2 different classes with same (apparent) initiative are sorted nicely, and not mixed
      pnj.final_initiative = math.random(pnj.initiative + 1, pnj.initiative + 6) + math.random()
      PNJtext[PNJnum].init.text = math.floor( pnj.final_initiative )
    end
  end

  -- shift to next slot
  PNJnum = PNJnum + 1

  return true
end


-- The PNJ are not displayed in the order they were generated: they are always 
-- sorted first by descending initiative value, then ascending ID value.
-- After a PNJ generation, this function sorts the PNJTable{} properly, then
-- re-print the GUI PNJ list completely.
-- Dead PNJs are not removed, and are still sorted and displayed
-- in the slot they were when alive.
-- returns nothing.
function sortAndDisplayPNJ()

  -- sort PNJ by descending initiative value, then ascending ID value
  table.sort( PNJTable, 
    function (a,b)
      if (a.final_initiative ~= b.final_initiative) then return (a.final_initiative > b.final_initiative) 
      else return (a.id < b.id) end
    end)

  -- then display PNJ table completely	
  for i=1,PNJmax do  

    if (i>=PNJnum) then

      -- erase unused slots (at the end of the list)
      PNJtext[i].done.checkbox.reset = true
      PNJtext[i].id.text = ""
      PNJtext[i].class.text = ""
      PNJtext[i].init.text = ""
      PNJtext[i].roll.text = "";
      PNJtext[i].dmg.text = "";
      PNJtext[i].armor.text = "";
      PNJtext[i].hits.text = "";
      PNJtext[i].endfordexfight.text = ""
      PNJtext[i].def.text = ""
      PNJtext[i].goal.text = ""
      PNJtext[i].stance.text = ""
      PNJtext[i].weapon.text = ""
      PNJtext[i].dmg.text2 = ""
      PNJtext[i].dmg.text3 = ""

    else

      pnj = PNJTable[i]
      PNJtext[i].class.text = pnj.class;

      -- cosmetic: do not display an init value if equal to previous one
      if (i==1) then PNJtext[i].init.text = math.floor( pnj.final_initiative ); end
      if (i>=2) then
        if ( math.floor( pnj.final_initiative ) ~= math.floor( PNJTable[i-1].final_initiative ) )
        then PNJtext[i].init.text = math.floor( pnj.final_initiative )
        else PNJtext[i].init.text = ""
        end
      end

      if (pnj.is_dead) then
        PNJtext[i].done.checkbox.set = true
        PNJtext[i].id.text = pnj.id
        PNJtext[i].roll.text = "--";
        PNJtext[i].dmg.text = "--";
        PNJtext[i].armor.text = "--";
        PNJtext[i].hits.text = "--";
        PNJtext[i].endfordexfight.text = "--"
        PNJtext[i].def.text = "--"
        PNJtext[i].goal.text = "--"
        PNJtext[i].stance.text = "--"
        PNJtext[i].weapon.text = "--"
        PNJtext[i].dmg.text2 = ""
        PNJtext[i].dmg.text3 = ""
        
      else

        if (PNJTable[i].done) then PNJtext[i].done.checkbox.set = true else PNJtext[i].done.checkbox.reset = true end

        PNJtext[i].id.text = pnj.id
        PNJtext[i].dmg.text = pnj.dmg .. "D";

        -- display roll for PNJ (not for PJ)
        if not pnj.PJ then
          PNJtext[i].roll.text = pnj.roll:getRoll();
          PNJtext[i].dmg.text2 = pnj.roll:getVPText();
          PNJtext[i].dmg.text3 = pnj.roll:getDamageText();
        else
          PNJtext[i].roll.text = ""
          PNJtext[i].dmg.text2 = ""
          PNJtext[i].dmg.text3 = ""
        end

        -- PJ are displayed in a different color
        updateLineColor(i)

        if (pnj.armor==0) then PNJtext[i].armor.text = "-" else PNJtext[i].armor.text = pnj.armor .. "D"; end
        PNJtext[i].hits.text = pnj.hits;
        PNJtext[i].endfordexfight.text = pnj.intelligence .." ".. pnj.endurance .." ".. pnj.force .. "\n" .. pnj.dex .." ".. pnj.fight .. " " .. pnj.perception;
        PNJtext[i].def.text = pnj.final_defense;
        PNJtext[i].goal.text = pnj.final_goal;
        PNJtext[i].stance.text = pnj.stance;
        PNJtext[i].weapon.text = pnj.weapon or "";
        
      end
    end

    -- all this resets the current focus
    lastFocus 		= focus
    focus     		= nil
    focusTarget   	= nil
    focusAttackers  	= {}

  end 

end

-- remove dead PNJs from the PNJTable{}, but keeps all other PNJs
-- in the same order. Reduces PNJnum index value accordingly.
-- return true if a dead PNJ was actually removed, false if none was found.
-- Does not re-print the PNJ list on the screen. 
function removeDeadPNJ()

  local has_removed =  false
  local a_change_occured = true -- a priori

  while (a_change_occured) do
    a_change_occured = false -- might change below
    local i = 1
    while (PNJTable[i]) do
      if PNJTable[i].is_dead then
        
        -- we are about to remove a PNJ. If this PNJ is currently a target, or attacking someone,
        -- cleanup these tables first
        -- FIXME
        
        a_change_occured = true
        has_removed = true
        local j=i+1
        while PNJTable[j] do
          -- erase PNJ with the next one in the list
          PNJTable[j-1] = PNJTable[j]
          j = j + 1
        end
        PNJnum = PNJnum - 1
        PNJTable[PNJnum] = nil
      end
      i = i + 1
    end
  end
  thereIsDead = false
  return has_removed
end

-- Check if all PNJs have played (the "done" checkbox is checked for all, 
-- including dead PNJs as well)
-- If so, calls the nextRound() function.
-- Return true or false depending on what was done 
function checkForNextRound()
  	local goNextRound = true -- a priori, might change below
  	for i=1,PNJnum-1 do if not PNJTable[i].done then goNextRound = false end end
  	nextFlash = goNextRound
  	return goNextRound
	end

-- roll a d20 dice for the ith-PNJ and display the result in the grid
function reroll(i)

    -- do not roll for PJs....
    if PNJTable[i].PJ then 
    PNJtext[i].roll.text 	= ""
    PNJtext[i].dmg.text2 	= ""
    PNJtext[i].dmg.text3 	= ""
    updateLineColor(i)
    return 
    end

    -- get defense of the target, if a target was selected
    local defense = nil
    local index = findPNJ( PNJTable[i].target )
    if index then defense = PNJTable[ index ].final_defense end

    -- roll D20
    PNJTable[i].roll = Roll.new( PNJTable[i].final_goal, defense, PNJTable[i].dmg )
    
    -- display it, with proper color	
    PNJtext[i].roll.text 		= PNJTable[i].roll:getRoll()
    PNJtext[i].dmg.text2 		= PNJTable[i].roll:getVPText()
    PNJtext[i].dmg.text3 		= PNJTable[i].roll:getDamageText()
    updateLineColor(i)
  
    end


-- Increase and display round number, reset all "done" checkboxes (except for
-- dead PNJs which are considered as "done" by default), and reset DEFENSE values. 
-- Returns nothing.
function nextRound()

    math.randomseed( os.time() )

    -- increase round
    roundNumber = roundNumber + 1
    view.s.t.round.text = tostring(roundNumber)
    view.s.t.round.color= color.red

    -- set timer
    nextFlash = false
    roundTimer = 0
    newRound = true

    -- reset defense & done checkbox
    for i=1,PNJnum-1 do

      if (not PNJTable[i].is_dead) then

        PNJTable[i].done = false
        PNJtext[i].done.checkbox.reset = true

        PNJTable[i].defmalus = 0
        PNJTable[i].final_defense = PNJTable[i].defense + PNJTable[i].defstancemalus
        PNJtext[i].def.text = PNJTable[i].final_defense;

        if (not PNJTable[i].PJ) then reroll (i) end

      else

        PNJTable[i].done = true 				-- a dead character is done
        PNJtext[i].done.checkbox.set = true

      end

      updateLineColor(i)

    end

    end

-- create one instance of each PJ
function createPJ()

    for classname,t in pairs(templateArray) do
      if t.PJ then generateNewPNJ(classname) end
    end

    sortAndDisplayPNJ()

    end


local tableAccents = {}
    tableAccents["à"] = "a" tableAccents["á"] = "a" tableAccents["â"] = "a" tableAccents["ã"] = "a"
    tableAccents["ä"] = "a" tableAccents["ç"] = "c" tableAccents["è"] = "e" tableAccents["é"] = "e"
    tableAccents["ê"] = "e" tableAccents["ë"] = "e" tableAccents["ì"] = "i" tableAccents["í"] = "i"
    tableAccents["î"] = "i" tableAccents["ï"] = "i" tableAccents["ñ"] = "n" tableAccents["ò"] = "o"
    tableAccents["ó"] = "o" tableAccents["ô"] = "o" tableAccents["õ"] = "o" tableAccents["ö"] = "o"
    tableAccents["ù"] = "u" tableAccents["ú"] = "u" tableAccents["û"] = "u" tableAccents["ü"] = "u"
    tableAccents["ý"] = "y" tableAccents["ÿ"] = "y" tableAccents["À"] = "A" tableAccents["Á"] = "A"
    tableAccents["Â"] = "A" tableAccents["Ã"] = "A" tableAccents["Ä"] = "A" tableAccents["Ç"] = "C"
    tableAccents["È"] = "E" tableAccents["É"] = "E" tableAccents["Ê"] = "E" tableAccents["Ë"] = "E"
    tableAccents["Ì"] = "I" tableAccents["Í"] = "I" tableAccents["Î"] = "I" tableAccents["Ï"] = "I"
    tableAccents["Ñ"] = "N" tableAccents["Ò"] = "O" tableAccents["Ó"] = "O" tableAccents["Ô"] = "O"
    tableAccents["Õ"] = "O" tableAccents["Ö"] = "O" tableAccents["Ù"] = "U" tableAccents["Ú"] = "U"
    tableAccents["Û"] = "U" tableAccents["Ü"] = "U" tableAccents["Ý"] = "Y"
 
-- Strip accents from a string
function string.stripAccents( str )
        
    local normalizedString = ""
 
    for strChar in string.gfind(str, "([%z\1-\127\194-\244][\128-\191]*)") do
        if tableAccents[strChar] ~= nil then
            normalizedString = normalizedString..tableAccents[strChar]
        else
            normalizedString = normalizedString..strChar
        end
    end
        
    return normalizedString
 
    end

-- read scenario txt file and build dictionnary
function readScenario( filename )

	local ignore = { "le", "la" , "les", "un" , "une", "des", "ce", "cet", "cette", "ces", "celles", "ca" , "si", "se" , "son", "de" ,
			 "sans", "dans", "pour", "par", "l", "a", "y", "d", "m", "n", "il", "elle", "elles", "ils", "du", "mais", "pour", 
			 "quand", "quoi", "ma", "ta", "ton", "tes", "ni", "ne" , "qui", "que", "qu"
			}

	local reject = function(word) for _,v in ipairs(ignore) do if v == word then return true end end return false end 
 
	-- stack of positions when reading scenario text
	-- each element is a triplet ( level, x , y )
	local stack = {}

	-- insert a default position on the stack (the center of the image)
	table.insert( stack, { level=0, xy="((".. math.floor(W / 2) .. "," .. math.floor(H / 2) .. "))" } )

	local linecount = 0
	for line in io.lines(filename) do

		linecount = linecount + 1

		-- replace accentuated characters
		line = string.stripAccents( line )

		-- determine level of the line
		local i , level = 1 , 0; while string.sub(line,i,i) == '\t' do level = level + 1; i = i + 1 ; end

		-- get level currently in the stack
		local lastelement = stack[ table.getn( stack ) ] 
		local lastlevel = lastelement.level -- we assume there is always at least one element

		-- check if a position is present on the line
		local newposition = string.match(line, "[(][(]%s*%d+%s*,%s*%d+%s*[)][)]" )

		-- compare levels
		if lastlevel == level then

  			-- if new position then replace it in the stack
  			-- this becomes the new position for this level
  			if newposition then
				table.remove( stack ) -- pop
				table.insert( stack, { level=level , xy = newposition } ) -- push
  			else
  			-- otherwise take the existing one
    				newposition = lastelement.xy
  			end
  
		elseif level > lastlevel then
  
			assert(level == lastlevel + 1, "scenario file syntax error: 2 levels are not consecutive at line " .. linecount)
  			if newposition then
    				-- add the new position to the stack
    				-- this becomes the new position at that level
    				table.insert( stack, { level=level, xy=newposition } ) -- push
  			else
    				-- otherwise push the new level with the same position
				table.insert( stack, { level=level, xy=lastelement.xy } )
				newposition = lastelement.xy
  			end
  
		else -- level < lastlevel

  			-- pop the stack until the proper level is reached
  			repeat
        			table.remove( stack )
				lastlevel = stack[ table.getn( stack ) ].level 
  			until level == lastlevel 

  			if newposition then
    				-- if new position, it becomes the new reference at this level
    				table.remove( stack ) -- pop
    				table.insert( stack, { level=level, xy=newposition } ) -- push
  			else
    				-- otherwise take the one from the stack
				newposition = lastelement.xy
  			end

		end

		-- from now on, newposition holds the actual 
		-- position to use on this node

		-- parse all words of the line (ignore all special characters)
		-- insert them in the dictionnary, with a couple { position , level } 
		local pos = { p = newposition, l = level } 
		for word in string.gmatch( line , "%a+" ) do
   			word = string.lower( word )
			if not reject(word) then -- we do not store common words 
   			 if dictionnary[word] then table.insert( dictionnary[word] , pos )
   			 else dictionnary[word] = { pos } end
			end
		end

	end -- end 'for line' ... go next line 

	end

options = { { opcode="-b", longopcode="--base", mandatory=false, varname="baseDirectory", value=true, default="." , 
		desc="Path to a base (network) directory, common with projector" },
	    { opcode="-d", longopcode="--debug", mandatory=false, varname="debug", value=false, default=false , 
		desc="Run in debug mode"},
	    { opcode="-l", longopcode="--log", mandatory=false, varname="log", value=false, default=false , 
		desc="Log to file (fading.log) instead of stdout"},
	    { opcode="-a", longopcode="--ack", mandatory=false, varname="acknowledge", value=false, default=false ,
		desc="With FS mobile: Send an automatic acknowledge reply for each message received"},
	    { opcode="-p", longopcode="--port", mandatory=false, varname="port", value=true, default=serverport,
		desc="Specify server local port, by default 12345" },
	    { opcode="", mandatory=true, varname="fadingDirectory" , desc="Path to scenario directory"} }
	    
--
-- Main function
-- Load PNJ class file, print (empty) GUI, then go on
--
function love.load( args )

    -- main window layout
    layout = mainLayout:new()

    -- parse arguments
    local parse = doParse( args )

    -- get images & scenario directory, provided at command line
    baseDirectory = parse.baseDirectory 
    fadingDirectory = parse.arguments[1]
    debug = parse.debug
    serverport = parse.port
    ack = parse.acknowledge
    sep = '/'

    -- log file
    if parse.log then
      logFile = io.open("fading.log","w")
      io.output(logFile)
    end

    -- GUI initializations...
    yui.UI.registerEvents()
    love.window.setTitle( "Fading Suns Combat Tracker" )

    -- adjust number of rows in screen
    PNJmax = math.floor( viewh / 42 )

    -- some adjustments on different systems
    if love.system.getOS() == "Windows" then

    	W, H = love.window.getDesktopDimensions()
    	W, H = W*0.98, H*0.92 

	messagesH		= H - 22
	snapshotH 		= messagesH - snapshotSize - snapshotMargin

        PNJmax = 14 
	keyZoomIn, keyZoomOut = ':', '!'

    end

    love.window.setMode( W  , H  , { fullscreen=false, resizable=true, display=1} )
    love.keyboard.setKeyRepeat(true)

    -- parse data file, 
    -- initialize class template list  and dropdown list (opt{}) at the same time
    local i = 1
    local opt = {}

    Class = function( t )
      if not t.class then error("need a class attribute (string value) for each class entry") end
      templateArray[t.class] = t 
      if not t.PJ then 		-- only display PNJ classes in Dropdown list, not PJ
        opt[i] = t.class ;
        i = i  + 1
      end  
    end

    dofile "fading2/data"

    local current_class = opt[1]

    -- load fonts
    fontDice = love.graphics.newFont("yui/yaoui/fonts/OpenSans-ExtraBold.ttf",90)
    fontRound = love.graphics.newFont("yui/yaoui/fonts/OpenSans-Bold.ttf",12)
    fontSearch = love.graphics.newFont("yui/yaoui/fonts/OpenSans-ExtraBold.ttf",16)
   
    -- create view structure
    love.graphics.setBackgroundColor( 255, 255, 255 )
    view = yui.View(0, 0, vieww, viewh, {
        margin_top = 5,
        margin_left = 5,
	yui.Stack({name="s",
            yui.Flow({name="t",
                yui.HorizontalSpacing({w=10}),
                yui.Button({name="nextround", text="  Next Round  ", size=size, black = true, 
			onClick = function(self) if self.button.black then return end 
				 		 if checkForNextRound() then nextRound() end end }),
                yui.Text({text="Round #", size=size, bold=1, center = 1}),
                yui.Text({name="round", text=tostring(roundNumber), size=32, w = 50, bold=1, color={0,0,0} }),
                yui.FlatDropdown({options = opt, size=size-2, onSelect = function(self, option) current_class = option end}),
                yui.HorizontalSpacing({w=10}),
                yui.Button({text=" Create ", size=size, onClick = function(self) return generateNewPNJ(current_class) and sortAndDisplayPNJ() end }),
                yui.HorizontalSpacing({w=50}),
                yui.Button({name = "rollatt", text="     Roll Attack     ", size=size, black = true,
			onClick = function(self) if self.button.black then return end rollAttack("attack") end }), yui.HorizontalSpacing({w=10}),
                yui.Button({name = "rollarm", text="     Roll  Armor     ", size=size, black = true,
			onClick = function(self) if self.button.black then return end rollAttack("armor") end }),
                yui.HorizontalSpacing({w=150}),
                yui.Button({name="cleanup", text="       Cleanup       ", size=size, onClick = function(self) return removeDeadPNJ() and sortAndDisplayPNJ() end }),
                yui.HorizontalSpacing({w=270}),
                yui.Button({text="    Quit    ", size=size, onClick = function(self) love.event.quit() end }),
              }), -- end of Flow
            createPNJGUIFrame(),
           }) -- end of Stack
        --})
      })


    nextButton = view.s.t.nextround
    attButton = view.s.t.rollatt
    armButton = view.s.t.rollarm
    clnButton = view.s.t.cleanup

    nextButton.button.black = true
    attButton.button.black = true
    armButton.button.black = true
    clnButton.button.black = true
    
    -- create socket and listen to any client
    server = socket.tcp()
    server:settimeout(0)
    server:bind(address, serverport)
    server:listen(10)
    tcpbin = socket.tcp()
    tcpbin:bind(address, serverport+1)
    tcpbin:listen(1)

    -- some initialization stuff
    generateUID = UIDiterator()

    -- create PJ automatically (1 instance of each!)
    -- later on, an image might be attached to them, if we find one
    createPJ()

    local PJImageNum, mapsNum, scenarioImageNum, scenarioTextNum = 0,0,0,0

    -- some small differences in windows: separator is not the same, and some weird completion
    -- feature in command line may add an unexpected doublequote char at the end of the path (?)
    -- that we want to remove
    if love.system.getOS() == "Windows" then
	    local n = string.len(fadingDirectory)
	    if string.sub(fadingDirectory,1,1) ~= '"' and 
		    string.sub(fadingDirectory,n,n) == '"' then
		    fadingDirectory=string.sub(fadingDirectory,1,n-1)
	    end
    	    sep = '\\'
    end

    -- default directory is 'fading2' (application folder)
    if not fadingDirectory or fadingDirectory == "" then fadingDirectory = "fading2" end
    io.write("base directory   : |" .. baseDirectory .. "|\n")
    addMessage("base directory : " .. baseDirectory .. "\n")
    io.write("fading directory : |" .. fadingDirectory .. "|\n")
    addMessage("fading directory : " .. fadingDirectory .. "\n")

    -- list all files in that directory, by executing a command ls or dir
    local allfiles = {}, command
    if love.system.getOS() == "OS X" then
	    io.write("ls '" .. baseDirectory .. sep .. fadingDirectory .. "' > .temp\n")
	    os.execute("ls '" .. baseDirectory .. sep .. fadingDirectory .. "' > .temp")
    elseif love.system.getOS() == "Windows" then
	    io.write("dir /b \"" .. baseDirectory .. sep .. fadingDirectory .. "\" > .temp\n")
	    os.execute("dir /b \"" .. baseDirectory .. sep ..fadingDirectory .. "\" > .temp ")
    end

    -- store output
    for line in io.lines (".temp") do table.insert(allfiles,line) end

    -- remove temporary file
    os.remove (".temp")

    -- create a new empty atlas (an array of maps)
    atlas = Atlas.new()

    -- check for scenario, snapshots & maps to load
    for k,f in pairs(allfiles) do

      io.write("scanning file : '" .. f .. "'\n")

      -- All files are optional. They can be:
      --   SCENARIO IMAGE: 	named scenario.jpg
      --   SCENARIO TEXT:	associated to this image, named scenario.txt
      --   MAPS: 		map*jpg or map*png, they are considered as maps and loaded as such
      --   PJ IMAGE:		pawnPJname.jpg or .png, they are considered as images for corresponding PJ
      --   PNJ DEFAULT IMAGE:	pawnDefault.jpg
      --   PAWN IMAGE:		pawn*.jpg or .png
      --   SNAPSHOTS:		*.jpg or *.png, all are snapshots displayed at the bottom part
      
      if f == 'scenario.txt' then 

	      readScenario( baseDirectory .. sep .. fadingDirectory .. sep .. f ) 
	      io.write("Loaded scenario at " .. baseDirectory .. sep .. fadingDirectory .. sep .. f .. "\n")
	      scenarioTextNum = scenarioTextNum + 1

      elseif f == 'scenario.jpg' then

	local s = Map:new()
	s:load{ kind="scenario", filename=baseDirectory .. sep .. fadingDirectory .. sep .. f }
	--atlas:addMap( s )
	layout:addWindow( s , false )
	io.write("Loaded scenario image file at " .. baseDirectory .. sep .. fadingDirectory .. sep .. f .. "\n")
	scenarioImageNum = scenarioImageNum + 1
	table.insert( snapshots[2].s, s ) 

      elseif f == 'pawnDefault.jpg' then

	defaultPawnSnapshot = loadSnap( baseDirectory .. sep ..fadingDirectory .. sep .. f )  
	table.insert( snapshots[3].s, defaultPawnSnapshot ) 

      elseif string.sub(f,-4) == '.jpg' or string.sub(f,-4) == '.png'  then

        if string.sub(f,1,4) == 'pawn' then

		local s = loadSnap( baseDirectory .. sep .. fadingDirectory .. sep .. f )  
		table.insert( snapshots[3].s, s ) 

		local pjname = string.sub(f,5, f:len() - 4 )
		io.write("Looking for PJ " .. pjname .. "\n")
		local index = findPNJByClass( pjname ) 
		if index then
			PNJTable[index].snapshot = s  
			PJImageNum = PJImageNum + 1
		end

	elseif string.sub(f,1,3) == 'map' then

	  local s = Map:new()
	  s:load{ filename=baseDirectory .. sep ..fadingDirectory .. sep .. f } 
	  --atlas:addMap( s )
	  layout:addWindow( s , false )
	  table.insert( snapshots[2].s, s ) 
	  mapsNum = mapsNum + 1

 	else

	  table.insert( snapshots[1].s, loadSnap( baseDirectory .. sep ..fadingDirectory .. sep .. f ) ) 
	  
        end

      end

    end

    io.write("Loaded " .. #snapshots[1].s .. " snapshots, " .. mapsNum .. " maps, " .. PJImageNum .. " PJ images, " .. scenarioImageNum .. " scenario image, " .. 
    		scenarioTextNum .. " scenario text\n" )

    addMessage("Loaded " .. #snapshots[1].s .. " snapshots, " .. mapsNum .. " maps, " .. PJImageNum .. " PJ images, " .. scenarioImageNum .. " scenario image, " .. 
    		scenarioTextNum .. " scenario text\n" )
	 
  -- create a reverted table of faces, in which point numbers are index,
  -- not value. This will ease face retrieval when knowing the points
  d6.revertedfaces = {}
  for i=1,#d6.faces do
   d6.revertedfaces[i] = {}
    for k,v in ipairs( d6.faces[i]) do
      d6.revertedfaces[i][v] = true
    end
  end

end


-- given 4 points by their index on the star, retrieve the number of
-- the corresponding face
function whichFace(i1,i2,i3,i4)
  for i=1,#d6.faces do
   if d6.revertedfaces[i][i1] and 
	  d6.revertedfaces[i][i2] and
	  d6.revertedfaces[i][i3] and
	  d6.revertedfaces[i][i4] then return i end
   end	  
   return nil
   end

