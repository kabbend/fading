
-- interface import
local utf8 		= require 'utf8'
local socket 		= require 'socket'	-- general networking
local parser    	= require 'parse'	-- parse command line arguments
local tween		= require 'tween'	-- tweening library (manage transition states)
local yui 		= require 'yui.yaoui' 	-- graphical library on top of Love2D
local scenario 		= require 'scenario'	-- read scenario file and perform text search
local rpg 		= require 'rpg'		-- code related to the RPG itself
local mainLayout 	= require 'layout'	-- global layout to manage windows
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	-- widgets components

-- specific window classes
local Help			= require 'help'		-- Help window
local notificationWindow 	= require 'notificationWindow'	-- notifications
local iconWindow		= require 'iconWindow'		-- grouped 'Action'/'Histoire' icons
local Dialog			= require 'dialog'		-- dialog with players 
local setupWindow		= require 'setup'		-- setup/configuration information 
local iconRollWindow		= require 'iconRoll'		-- dice icon and launching 
local projectorWindow		= require 'projector'		-- project images to players 

layout = mainLayout:new()

-- dice3d code
require	'fading2/dice/base'
require	'fading2/dice/loveplus'
require	'fading2/dice/vector'
require 'fading2/dice/render'
require 'fading2/dice/stars'
require 'fading2/dice/geometry'
require 'fading2/dice/diceview'
require 'fading2/dice/light'
require 'fading2/dice/default/config'

--
-- GLOBAL VARIABLES
--

debug = true 

-- main layout
currentWindowDraw 	= nil
intW			= 2 	-- interval between windows

-- main screen size
W, H = 1440, 800 	-- main window size default values (may be changed dynamically on some systems)
local iconSize = theme.iconSize 
sep = '/'

-- tcp information for network
address, serverport	= "*", "12345"		-- server information
server			= nil			-- server tcp object
ip,port 		= nil, nil		-- projector information
clients			= {}			-- list of clients. A client is a couple { tcp-object , id } where id is a PJ-id or "*proj"
projector		= nil			-- direct access to tcp object for projector
projectorId		= "*proj"		-- special ID to distinguish projector from other clients
chunksize 		= (8192 - 1)		-- size of the datagram when sending binary file
fullBinary		= false			-- if true, the server will systematically send binary files instead of local references

-- messages zone
messages 		= {}
messagesH		= H 

-- snapshots
snapshots    = {}
snapshots[1] = { s = {}, index = 1, offset = 0 } 	-- small snapshots at the bottom, for general images
snapshots[2] = { s = {}, index = 1, offset = 0 }	-- small snapshots at the bottom, for scenario & maps
snapshots[3] = { s = {}, index = 1, offset = 0 }	-- small snapshots at the bottom, for PNJ classes 
snapshots[4] = { s = {}, index = 1, offset = 0 }	-- small snapshots at the bottom, for pawn images
snapText = { "GENERAL IMAGES", "TACTICAL MAPS", "PNJ CLASSES", "PAWN IMAGES" }
currentSnap		= 1				-- by default, we display images
snapshotSize 		= 70 				-- w and h of each snapshot
snapshotMargin 		= 7 				-- space between images and screen border
snapshotH 		= messagesH - snapshotSize - snapshotMargin

HC = H - 4 * intW - 3 * iconSize - snapshotSize
WC = 1290 - 2 * intW
viewh = HC 		-- view height
vieww = W - 260		-- view width
size = 19 		-- base font size
screenMargin = 40	-- screen margin in map mode

-- various mouse movements
mouseMove		= false
dragMove		= false
dragObject		= { originWindow = nil, object = nil, snapshot = nil }

-- pawns and PJ snapshots
pawnMove 		= nil		-- pawn currently moved by mouse movement
defaultPawnSnapshot	= nil		-- default image to be used for pawns
pawnMaxLayer		= 1
pawnMovingTime		= 2		-- how many seconds to complete a movement on the map ?

-- projector snapshot size
layout.H1, layout.W1 = 140, 140

-- some GUI buttons whose color will need to be changed at runtime
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
keyZoomIn		= ':'			-- default on macbookpro keyboard. Changed at runtime for windows
keyZoomOut 		= '=' 			-- default on macbookpro keyboard. Changed at runtime for windows
mapOpeningSize		= 400			-- approximate width size at opening
mapOpeningXY		= 250			-- position to open next map, will increase with maps opened
mapOpeningStep		= 100			-- increase x,y at each map opening

keyPaste		= 'lgui'		-- on mac only

-- current text input
textActiveCallback		= nil			-- if set, function to call with keyboard input (argument: one char)
textActiveBackspaceCallback	= nil			-- if set, function to call on a backspace (suppress char)
textActivePasteCallback		= nil			-- if set, function to call on a paste 
textActiveCopyCallback		= nil			-- if set, function to call on a copy clipboard 
textActiveLeftCallback		= nil			
textActiveRightCallback		= nil			

-- array of PJ and PNJ characters
-- Only PJ at startup (PNJ are created upon user request)
-- Maximum number is PNJmax
-- A Dead PNJ counts as 1, except if explicitely removed from the list
PNJTable 	= {}		
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
diceKind 	    = ""	-- kind of dice (black for 'attack', white for 'armor') -- unused
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

local glowCode = [[
extern vec2 size;
extern int samples = 5; // pixels per axis; higher = bigger glow, worse performance
extern float quality = 2.5; // lower = smaller glow, better quality
 
vec4 effect(vec4 colour, Image tex, vec2 tc, vec2 sc)
{
  vec4 source = Texel(tex, tc);
  vec4 sum = vec4(0);
  int diff = (samples - 1) / 2;
  vec2 sizeFactor = vec2(1) / size * quality;
  
  for (int x = -diff; x <= diff; x++)
  {
    for (int y = -diff; y <= diff; y++)
    {
      vec2 offset = vec2(x, y) * sizeFactor;
      sum += Texel(tex, tc + offset);
    }
  }
  
  return ((sum / (samples * samples)) + source) * colour;
} ]]
 
-- we write only in debug mode
local oldiowrite = io.write
function io.write( data ) if debug then oldiowrite( data ) end end

function splitFilename(strFilename)
	--return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
	return string.match (strFilename,"[^/]+$")
end

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
	setmetatable(c, {__index = function (t, k) return Csearch(k, {a,b}) end})
	c.__index = c
	function c:new (o) o = o or {}; setmetatable(o, c); return o end
	return c
	end

-- some convenient file loading functions (based on filename or file descriptor)
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

function Snapshot:new( t ) -- create from filename or file object (one mandatory), and kind 
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  assert( new.filename or new.file )
  local image
  if new.filename then 
	image = loadDistantImage( new.filename )
	new.is_local = false
	new.baseFilename = string.gsub(new.filename,baseDirectory,"")
	new.displayFilename = splitFilename(new.filename)
  else 
	image = loadLocalImage( new.file )
	new.is_local = true
	new.baseFilename = new.file:getFilename() 
	new.displayFilename = splitFilename(new.file:getFilename())
  end
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  local img = lgn(lin(lfn(image, 'img', 'file')), { mipmaps=true } ) 
  pcall( function() img:setMipmapFilter( "nearest" ) end )
  new.im = img
  new.w, new.h = new.im:getDimensions()
  local f1, f2 = snapshotSize / new.w, snapshotSize / new.h
  new.snapmag = math.min( f1, f2 )
  new.selected = false
  return new
end

--
--  Pawn object 
--  A pawn holds the image, with proper scale defined at pawn creation on the map,
--  along with the ID of the corresponding PJ/PNJ.
--  Both sizes of the pawn image (sizex and sizey) are computed to follow the image
--  original height/width ratio. Sizex is directly defined by the MJ at pawn creation,
--  using the arrow on the map, sizey is then derived from it
-- 
Pawn = {}
function Pawn:new( id, snapshot, width , x, y ) 
  local new = {}
  setmetatable(new,self)
  self.__index = self 
  new.id = id
  new.layer = pawnMaxLayer 
  new.x, new.y = x or 0, y or 0 		-- current pawn position, relative to the map
  new.moveToX, new.moveToY = new.x, new.y 	-- destination of a move 
  new.snapshot = snapshot
  new.sizex = width 				-- width size of the image in pixels, for map at scale 1
  local w,h = new.snapshot.w, new.snapshot.h
  new.sizey = new.sizex * (h/w) 
  local f1,f2 = new.sizex/w, new.sizey/h
  new.f = math.min(f1,f2)
  new.offsetx = (new.sizex + 3*2 - w * new.f ) / 2
  new.offsety = (new.sizey + 3*2 - h * new.f ) / 2
  new.PJ = false
  new.color = theme.color.white
  return new
  end

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
  self.class = "map"
  self.layout = t.layout
 
  -- snapshot part of the object
  assert( t.filename or t.file )
  local image
  if t.filename then
	self.filename = t.filename 
	image = loadDistantImage( self.filename )
	self.is_local = false
	self.baseFilename = string.gsub(self.filename,baseDirectory,"")
	self.displayFilename = splitFilename(self.filename)
  else 
	self.file = t.file
	image = loadLocalImage( self.file )
	self.is_local = true
	self.baseFilename = self.file:getFilename() 
	self.displayFilename = splitFilename(self.file:getFilename())
  end
  self.title = self.displayFilename or ""
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  local success, img 
  if self.kind == "map" then
  	success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file')), { mipmaps=true } ) end)
  	pcall(function() img:setMipmapFilter( "nearest" ) end)
  	local mode, sharpness = img:getMipmapFilter( )
  	io.write("map load: mode, sharpness = " .. tostring(mode) .. " " .. tostring(sharpness) .. "\n")
  else
	success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file')) ) end)
  end
  self.im = img
  self.w, self.h = self.im:getDimensions()
  local f1, f2 = snapshotSize / self.w, snapshotSize / self.h
  self.snapmag = math.min( f1, f2 )
  self.selected = false
  
  -- window part of the object
  self.zoomable = true
  self.whResizable = true
  self.mag = self.w / mapOpeningSize	-- we set ratio so we stick to the required opening size	
  self.x, self.y = self.w/2, self.h/2
  Window.translate(self,mapOpeningXY-W/2,mapOpeningXY-H/2) -- set correct position
 
  mapOpeningXY = mapOpeningXY + mapOpeningStep
 
  -- specific to the map itself
  if self.kind == "map" then self.mask = {} else self.mask = nil end
  self.step = 50
  self.pawns = {}
  self.basePawnSize = nil -- base size for pawns on this map (in pixels, for map at scale 1)
  self.shader = love.graphics.newShader( glowCode ) 
  self.quad = nil
  self.translateQuadX, self.translateQuadY = 0,0

  -- outmost limits of the current mask
  self.maskMinX, self.maskMaxX, self.maskMinY, self.maskMaxY = 100 * self.w , -100 * self.w, 100 * self.h, - 100 * self.h 
end

function Map:setQuad(x1,y1,x2,y2)
	if not x1 then 
		-- setQuad() with no arguments removes the quad 
		self.quad = nil 
		self.translateQuadX, self.translateQuadY = 0,0
		self.w, self.h = self.im:getDimensions()
  		local f1, f2 = snapshotSize / self.w, snapshotSize / self.h
  		self.snapmag = math.min( f1, f2 )
		self.restoreX, self.restoreY, self.restoreMag = nil, nil, nil
		return
		end 
  	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
	local x1, y1 = math.floor((x1 - zx) * self.mag) , math.floor((y1 - zy) * self.mag)  -- convert to map coordinates
	local x2, y2 = math.floor((x2 - zx) * self.mag) , math.floor((y2 - zy) * self.mag)  -- convert to map coordinates
	if x1 > x2 then x1, x2 = x2, x1 end
	if y1 > y2 then y1, y2 = y2, y1 end
	local w, h = math.floor(x2 - x1), math.floor(y2 - y1)
	if x1 + w > self.w then w = self.w - x1 end
	if y1 + h > self.h then h = self.h - y1 end
	self.quad = love.graphics.newQuad(x1,y1,w,h,self.w,self.h)
	local px,py = self:WtoS(x1,y1)
	self.translateQuadX, self.translateQuadY = math.floor(x1), math.floor(y1) 
	io.write("creating quad x y w h (versus w h): " .. x1 .. " " .. y1 .. " " .. w .. " " .. h .. " " .. "(" .. self.w .. " " .. self.h .. ")\n")
	self.w, self.h = w, h
	local nx,ny = self:WtoS(0,0)
	self:translate(px-nx,py-ny)
  	local f1, f2 = snapshotSize / self.w, snapshotSize / self.h
  	self.snapmag = math.min( f1, f2 )
	self.restoreX, self.restoreY, self.restoreMag = self.x, self.y, self.mag
	end

-- a Map move or zoom is a  bit more than a window move or zoom: 
-- We might send the same movement to the projector as well
function Map:move( x, y ) 
		self.x = x; self.y = y
		if atlas:isVisible(self) and not self.sticky then 
			tcpsend( projector, "CHXY " .. math.floor(self.x+self.translateQuadX) .. " " .. math.floor(self.y+self.translateQuadY) ) 
		end
	end

function Map:zoom( mag )
	if mag == 1 then
		-- +1, reduce size
		if self.mag < 1 then self.mag = self.mag + 0.1
		elseif self.mag >= 1 then self.mag = self.mag + 0.5 end
		if self.mag >= 20 then self.mag = 20 end
	elseif mag == -1 then
		-- -1, augment size
		if self.mag > 1 then self.mag = self.mag - 0.5 
		elseif self.mag <= 1 then self.mag = self.mag - 0.1 end
		if self.mag <= 0.1 then self.mag = 0.1 end
	end
	if atlas:isVisible(self) and not self.sticky then tcpsend( projector, "MAGN " .. 1/self.mag ) end	
	end

function Map:drop( o )
	local obj = o.object
	if obj.class == "pnjtable" or obj.class == "pnj" then -- receiving a PNJ either from PNJ list or from snapshot PNJ Class bar 
		if not self.basePawnSize then addMessage("No pawn size defined on this map. Please define it with Ctrl+mouse")
		else
		  local x, y = love.mouse.getPosition()
  		  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
		  local px, py = (x - zx) * self.mag , (y - zy) * self.mag 

		  -- maybe we need to create the PNJ before
		  local id
		  if obj.class == "pnj" then
			id  = generateNewPNJ( obj.rpgClass.class )
			if id then sortAndDisplayPNJ() end
		  else
			id = obj.id
		  end
		  io.write("map drop 1: object is pnj with id " .. id .. "\n")
		  if not id then return end

		  local p = self:createPawns(0,0,0,id)  -- we create it at 0,0, and translate it afterwards
		  if p then 
			p.x, p.y = px + self.translateQuadX ,py + self.translateQuadY 
		  	io.write("map drop 2: creating pawn " .. id .. "\n")
			end

		  -- send it to projector
		  if p and atlas:isVisible(self) then	
	  		local flag
	  		if p.PJ then flag = "1" else flag = "0" end
			local i = findPNJ( p.id )
	  		local f = p.snapshot.baseFilename -- FIXME: what about pawns loaded dynamically ?
	  		io.write("PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. 
					math.floor(p.sizex * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f .. "\n")
	  		tcpsend( projector, "PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. 
					math.floor(p.sizex * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f)
			end
		end
	end 
	end

function Map:maximize()

	-- if values are stored for restoration, we restore
	if self.restoreX then
		self.x, self.y, self.mag = self.restoreX, self.restoreY, self.restoreMag
		self.restoreX, self.restoreY, self.restoreMag = nil,nil,nil,nil 
		return
	end

	-- store values for restoration
	self.restoreX, self.restoreY, self.restoreMag = self.x, self.y, self.mag

	if not self.mask or (self.mask and #self.mask == 0) then
		-- no mask, just center the window with scale 1:0
		self.x, self.y = self.w / 2, self.h / 2
		self.mag = 1.0
	else
		-- there are masks. We take the center of the combined masks
		self.x, self.y = (self.maskMinX + self.maskMaxX) / 2 - self.translateQuadX, (self.maskMinY + self.maskMaxY) / 2 - self.translateQuadY
		self.mag = 1.0
		io.write("maximize with masks: going to " .. self.x .. " " .. self.y .. "\n")
	end
	end

function Map:draw()

     local map = self
     currentWindowDraw = self

     local SX,SY,MAG = map.x, map.y, map.mag
     local x,y = -( SX * 1/MAG - W / 2), -( SY * 1/MAG - H / 2)
  

     if map.mask then	
       --love.graphics.setColor(100,100,50,200)
       if layout:getFocus() == map then
		love.graphics.setColor(200,200,100)
       else
		love.graphics.setColor(150,150,150)
       end	
       love.graphics.stencil( myStencilFunction, "increment" )
       love.graphics.setStencilTest("equal", 1)
     else
       --love.graphics.setColor(255,255,255,240)
       love.graphics.setColor(255,255,255)
     end

     love.graphics.setScissor(x,y,self.w/MAG,self.h/MAG) 
     if map.quad then
       love.graphics.draw( map.im, map.quad, x, y, 0, 1/MAG, 1/MAG )
     else
       love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )
     end

     if map.mask then
       love.graphics.setStencilTest("gequal", 2)
       love.graphics.setColor(255,255,255)
     if map.quad then
       love.graphics.draw( map.im, map.quad, x, y, 0, 1/MAG, 1/MAG )
     else
       love.graphics.draw( map.im, x, y, 0, 1/MAG, 1/MAG )
     end
       love.graphics.setStencilTest()
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
		     	if map.pawns[i].snapshot.im then
  		       		local zx,zy = (map.pawns[i].x - map.translateQuadX) * 1/map.mag + x , (map.pawns[i].y - map.translateQuadY) * 1/map.mag + y
				-- color is different depending on PJ/PNJ, and if the character has played this round or not, or has the focus
		       		if PNJTable[index].done then love.graphics.setColor(unpack(theme.color.green))
				elseif PNJTable[index].PJ then love.graphics.setColor(50,50,250) else love.graphics.setColor(250,50,50) end
		       		love.graphics.rectangle( "fill", zx, zy, (map.pawns[i].sizex+6) / map.mag, (map.pawns[i].sizey+6) / map.mag)
		       		if dead then 
					love.graphics.setColor(50,50,50,200) -- dead are grey
				else
					love.graphics.setColor( unpack(map.pawns[i].color) )  
				end
		       		nzx = zx + map.pawns[i].offsetx / map.mag
		       		nzy = zy + map.pawns[i].offsety / map.mag
				if index == focus then 	
  					love.graphics.setShader(self.shader)
  					self.shader:send("size",{100,100})
  				end
		       		love.graphics.draw( map.pawns[i].snapshot.im , nzx, nzy, 0, map.pawns[i].f / map.mag , map.pawns[i].f / map.mag )
				if index == focus then 	love.graphics.setShader() end
				-- display hits number and ID
		       		love.graphics.setColor(0,0,0)  
				local f = map.basePawnSize / 5
				local s = f / 22 
		       		love.graphics.rectangle( "fill", zx, zy, f / map.mag, 2 * f / map.mag)
		       		love.graphics.setColor(255,255,255) 
        			love.graphics.setFont(theme.fontSearch)
				love.graphics.print( PNJTable[index].hits , zx, zy , 0, s/map.mag, s/map.mag )
				love.graphics.print( PNJTable[index].id , zx, zy + f/map.mag , 0, s/map.mag, s/map.mag )
	     	     	end
		     end
	     end
     end

     -- print visible 
     if atlas:isVisible( map ) then
	local char = "V" -- a priori
	if map.sticky then char = "S" end -- stands for S(tuck)
        love.graphics.setColor(200,0,0,180)
        love.graphics.setFont(theme.fontDice)
	love.graphics.print( char , x + 5 , y + (40 / map.mag) , 0, 2/map.mag, 2/map.mag) -- bigger letters
     end

     -- print search zone if scenario
     if self.kind == "scenario" then
      	love.graphics.setColor(0,0,0)
      	love.graphics.setFont(theme.fontSearch)
      	love.graphics.printf(text, 800, H - 60, 400)
      	-- print number of the search result is needed
      	if searchIterator then love.graphics.printf( "( " .. searchIndex .. " [" .. string.format("%.2f", searchPertinence) .. "] out of " .. 
						           searchSize .. " )", 800, H - 40, 400) end
    end

    love.graphics.setScissor() 

    -- print window button bar
    self:drawBar()
    self:drawResize()

    -- print minimize/maximize icon
    local tx, ty = x + self.w / self.mag - iconSize , y + 3 
    tx, ty = math.min(tx,W-iconSize), math.max(ty,0)
    love.graphics.draw( theme.iconReduce, tx, ty )
    
end

function Map:getFocus() if self.kind == "scenario" then searchActive = true end end
function Map:looseFocus() if self.kind == "scenario" then searchActive = false end end

function Map:update(dt)	

	-- move pawns progressively, if needed
	-- restore their color (white) which may have been modified if they are current target of an arrow
	if self.kind =="map" then
		for i=1,#self.pawns do
			local p = self.pawns[i]
			if p.timer then p.timer:update(dt) end
			if p.x == p.moveToX and p.y == p.moveToY then p.timer = nil end -- remove timer in the end
			p.color = theme.color.white
		end	
	end

	Window.update(self,dt)

	end

-- remove a pawn from the list (different from killing the pawn)
function Map:removePawn( id )
	for i=1,#self.pawns do if self.pawns[i].id == id then table.remove( self.pawns , i ) ; break end end
	end

--
-- Create characters from PNJTable as pawns on the 'map', with the 'requiredSize' (in pixels on the screen) 
-- and around the position 'sx','sy' (expressed in pixel position in the screen)
--
-- createPawns() only create characters that are not already created on this 'map'. 
-- When new characters are created on a map with existing pawns, 'requiredSize' is ignored, replaced by 
-- the current value for existing pawns on the map.
--
-- createPawns() will create all characters of the existing list. But if 'id' is provided, it will 
-- only create this character
--
-- return the pawns array if multiple pawns requested, or the unique pawn if 'id' provided
--

function Map:setPawnSize( requiredSize )
  	local border = 3 -- size of a colored border, in pixels, at scale 1 (3 pixels on all sides)
  	local requiredSize = math.floor((requiredSize) * self.mag) - border*2
  	self.basePawnSize = requiredSize
	end

function Map:createPawns( sx, sy, requiredSize , id ) 

  local map = self

  local uniquepawn = nil

  local border = 3 -- size of a colored border, in pixels, at scale 1 (3 pixels on all sides)

  -- set to scale 1
  -- get actual size, without borders.
  requiredSize = math.floor((requiredSize) * map.mag) - border*2

  -- use the required size unless the map has pawns already. In this case, reuse the same size
  local pawnSize = map.basePawnSize or requiredSize 
  if not map.basePawnSize then map.basePawnSize = pawnSize end

  local margin = math.floor(pawnSize / 10) -- small space between 2 pawns

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

  for i=1,#PNJTable do

	 local p
	 local needCreate = true

	 -- don't create pawns for characters already dead...
	 if PNJTable[i].is_dead then needCreate = false end

	 -- check if pawn with same ID exists or not on the map
	 for k=1,#map.pawns do if map.pawns[k].id == PNJTable[i].id then needCreate = false; break; end end

	 -- limit creation to only 1 character if ID is provided
	 if id and (PNJTable[i].id ~= id) then needCreate = false end

	 if needCreate then
	  local f
	  if PNJTable[i].snapshot then
	  	p = Pawn:new( PNJTable[i].id , PNJTable[i].snapshot, pawnSize * PNJTable[i].sizefactor , a , b ) 
	  else
		assert(defaultPawnSnapshot,"no default image available. You should refrain from using pawns on the map...")
	  	p = Pawn:new( PNJTable[i].id , defaultPawnSnapshot, pawnSize * PNJTable[i].sizefactor , a , b ) 
	  end
	  p.PJ = PNJTable[i].PJ
	  map.pawns[#map.pawns+1] = p
	  io.write("creating pawn " .. i .. " with id " .. p.id .. " and inserting in map at rank " .. #map.pawns .. "\n")
	  if id then uniquepawn = p end

	  -- send to projector...
	  if not id and atlas:isVisible(map) then
	  	local flag
	  	if p.PJ then flag = "1" else flag = "0" end
		-- send over the socket
		if p.snapshot.is_local then
			tcpsendBinary{ file=p.snapshot.file }
	  		tcpsend( projector, "PEOF " .. p.id .. " " .. a .. " " .. b .. " " .. math.floor(pawnSize * PNJTable[i].sizefactor) .. " " .. flag )
		elseif fullBinary then
			tcpsendBinary{ filename=p.snapshot.filename }
	  		tcpsend( projector, "PEOF " .. p.id .. " " .. a .. " " .. b .. " " .. math.floor(pawnSize * PNJTable[i].sizefactor) .. " " .. flag )
		else
	  		local f = p.snapshot.filename
	  		f = string.gsub(f,baseDirectory,"")
	  		io.write("PAWN " .. p.id .. " " .. a .. " " .. b .. " " .. math.floor(pawnSize * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f .. "\n")
	  		tcpsend( projector, "PAWN " .. p.id .. " " .. a .. " " .. b .. " " .. math.floor(pawnSize * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f)
		end
	  end
	  -- set position for next image: we display pawns on 4x4 line/column around the mouse position
	  if i % 4 == 0 then
			a = starta 
			b = b + pawnSize + border*2 + margin
	  	else
			a = a + pawnSize + border*2 + margin	
	  end
	  end

  end

  if id then return uniquepawn else return map.pawns end

  end

-- return a pawn if position x,y on the screen (typically, the mouse), is
-- inside any pawn of the map. If several pawns at same location, return the
-- one with highest layer value
function Map:isInsidePawn(x,y)
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2) -- position of the map on the screen
  if self.pawns then
	local indexWithMaxLayer, maxlayer = 0, 0
	for i=1,#self.pawns do
		-- check that this pawn is still active/alive
		local index = findPNJ( self.pawns[i].id )
		if index then  
		  local lx,ly = self.pawns[i].x - self.translateQuadX, self.pawns[i].y - self.translateQuadY-- position x,y relative to the map, at scale 1
		  local tx,ty = zx + lx / self.mag, zy + ly / self.mag -- position tx,ty relative to the screen
		  local sizex = self.pawns[i].sizex / self.mag -- size relative to the screen
		  local sizey = self.pawns[i].sizey / self.mag -- size relative to the screen
		  if x >= tx and x <= tx + sizex and y >= ty and y <= ty + sizey and self.pawns[i].layer > maxlayer then
			maxlayer = self.pawns[i].layer
			indexWithMaxLayer = i
		  end
	  	end
  	end
	if indexWithMaxLayer == 0 then return nil else return self.pawns[ indexWithMaxLayer ] end
  end
end

--
-- Combat class
-- a Combat is a window which displays PNJ list and buttons 
--
Combat = Window:new{ class = "combat" , title = "COMBAT TRACKER" , wResizable = true, hResizable = true }

function Combat:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function Combat:draw()

  local alpha = 80
  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)

  -- draw background
  self:drawBack()

  love.graphics.setScissor(zx,zy,self.w/self.mag,self.h/self.mag) 
  view:draw()
 

  -- draw FOCUS if applicable
  love.graphics.setColor(0,102,0,alpha)
  if focus then love.graphics.rectangle("fill",PNJtext[focus].x+2,PNJtext[focus].y-5,WC - 5,42) end

  -- draw ATTACKERS if applicable
  love.graphics.setColor(174,102,0,alpha)
    if focusAttackers then
      for i,v in pairs(focusAttackers) do
        if v then
          local index = findPNJ(i)
          if index then 
		  love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,WC - 5,42) 
		  -- emphasize defense value, but only for PNJ
    		  if not PNJTable[index].PJ then
			  love.graphics.setColor(0,0,0,120)
		  	  love.graphics.rectangle("line",PNJtext[index].x+743,PNJtext[index].y-3, 26,39) 
		  end
		  PNJtext[index].def.color = { unpack(theme.color.white) }
    		  love.graphics.setColor(204,102,0,alpha)
	  end
        end
      end
    end 

    -- draw TARGET if applicable
    love.graphics.setColor(250,60,60,alpha*1.5)
    local index = findPNJ(focusTarget)
    if index then love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,WC - 5,42) end

    -- draw PNJ snapshot if applicable
    for i=1,#PNJTable do
      if PNJTable[i].snapshot then
       	    love.graphics.setColor(255,255,255)
	    local s = PNJTable[i].snapshot
	    local xoffset = s.w * s.snapmag * 0.5 / 2
	    love.graphics.draw( s.im , zx + 210 - xoffset , PNJtext[i].y - 2 , 0 , s.snapmag * 0.5, s.snapmag * 0.5 ) 
      end
    end

  if nextFlash then
    -- draw a blinking rectangle until Next button is pressed
    if flashSequence then
      love.graphics.setColor(250,80,80,alpha*1.5)
    else
      love.graphics.setColor(0,0,0,alpha*1.5)
    end
    love.graphics.rectangle("fill",PNJtext[1].x+1010,PNJtext[1].y-5,400,(#PNJTable)*43)
  end
  love.graphics.setScissor() 

  -- print bar
  self:drawBar()
  self:drawResize()

end

function Combat:update(dt)
	
	Window.update(self,dt)

  	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
	view:setElementPosition( view.layout[1], zx + 5, zy + 5 )
  	view:update(dt)
  	yui.update({view})

	end

function Combat:click(x,y)

  	local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)

	if (y - zy) >= 40 then -- clicking on buttons does not change focus

  	-- we assume that the mouse was pressed outside PNJ list, this might change below
  	lastFocus = focus
  	focus = nil
  	focusTarget = nil
  	focusAttackers = nil

  	-- check which PNJ was selected, depending on position on y-axis
  	  for i=1,#PNJTable do
    	  if (y >= PNJtext[i].y -5 and y < PNJtext[i].y + 42 - 5) then
      		PNJTable[i].focus = true
      		lastFocus = focus
      		focus = i
      		focusTarget = PNJTable[i].target
      		focusAttackers = PNJTable[i].attackers
      		-- this starts the arrow mode or the drag&drop mode, depending on x
	    	local s = PNJTable[i].snapshot
	    	local xoffset = s.w * s.snapmag * 0.5 / 2
		if x >= zx + 210 - xoffset and x <= zx + 210 + xoffset  then
		 dragMove = true
		 dragObject = { originWindow = self, 
				object = { class = "pnjtable", id = PNJTable[i].id },
				snapshot = PNJTable[i].snapshot
				}	
		else
        	 arrowMode = true
        	 arrowStartX = x
        	 arrowStartY = y
        	 arrowStartIndex = i
		end	
    	  else
      		PNJTable[i].focus = false
    	  end

	  end

	end

  	Window.click(self,x,y)		-- the general click function may set mouseMove, but we want
					-- to move only in certain circumstances, so we override this below

	-- resize supersedes focus
	if mouseResize then 
		focus = nil 
  		focusTarget = nil
  		focusAttackers = nil
	end

	if not focus and not mouseResize then
		-- want to move window 
		mouseMove = true
		arrowMode = false
		arrowStartX, arrowStartY = x, y
		arrowModeMap = nil
	elseif focus and not dragMove then
		mouseMove = false
        	arrowMode = true
	else
		mouseMove = false
        	arrowMode = false
	end
	
	if (y - zy) < 40 then 
        	arrowMode = false
	end

  	end

function Combat:drop( o )

	if o.object.class == "pnj" then
		generateNewPNJ( o.object.rpgClass.class )
		sortAndDisplayPNJ()
	end

	end

--
-- snapshotBarclass
-- a snapshotBar is a window which displays images
--
snapshotBar = Window:new{ class = "snapshot" , title = snapText[currentSnap] , wResizable = true }

function snapshotBar:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  return new
end

function snapshotBar:draw()

  self:drawBack()

  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  love.graphics.setColor(255,255,255)
  for i=snapshots[currentSnap].index, #snapshots[currentSnap].s do
	local x = zx + snapshots[currentSnap].offset + (snapshotSize + snapshotMargin) * (i-1) - (snapshots[currentSnap].s[i].w * snapshots[currentSnap].s[i].snapmag - snapshotSize) / 2
	if x > zx + self.w / self.mag  + snapshotSize then break end
	if x >= zx - snapshotSize then 
  		love.graphics.setScissor( zx, zy, self.w / self.mag, self.h / self.mag ) 
		if snapshots[currentSnap].s[i].selected then
  			love.graphics.setColor(unpack(theme.color.red))
			love.graphics.rectangle("line", 
				zx + snapshots[currentSnap].offset + (snapshotSize + snapshotMargin) * (i-1),
				zy + 5, 
				snapshotSize, 
				snapshotSize)
		end
		if currentSnap == 2 and snapshots[currentSnap].s[i].kind == "scenario" then
			-- do not draw scenario, ... 
		else
  			love.graphics.setColor(255,255,255)
			if currentSnap == 2 and snapshots[currentSnap].s[i].quad then
			love.graphics.draw( 	snapshots[currentSnap].s[i].im , 
				snapshots[currentSnap].s[i].quad,
				x ,
				zy - ( snapshots[currentSnap].s[i].h * snapshots[currentSnap].s[i].snapmag - snapshotSize ) / 2 + 2, 
			    	0 , snapshots[currentSnap].s[i].snapmag, snapshots[currentSnap].s[i].snapmag )
			else
			love.graphics.draw( 	snapshots[currentSnap].s[i].im , 
				x ,
				zy - ( snapshots[currentSnap].s[i].h * snapshots[currentSnap].s[i].snapmag - snapshotSize ) / 2 + 2, 
			    	0 , snapshots[currentSnap].s[i].snapmag, snapshots[currentSnap].s[i].snapmag )
			end
		end
  		love.graphics.setScissor() 
	end
  end
 
   -- print bar
   self:drawBar()

   -- print over text eventually
 
   love.graphics.setFont(theme.fontRound)
   local x,y = love.mouse.getPosition()
   local left = math.max(zx,0)
   local right = math.min(zx+self.w,W)
	
   if x > left and x < right and y > zy and y < zy + self.h then
	-- display text is over a class image
    	local index = math.floor(((x-zx) - snapshots[currentSnap].offset) / ( snapshotSize + snapshotMargin)) + 1
    	if index >= 1 and index <= #snapshots[currentSnap].s then
		if currentSnap == 3 then
			local size = theme.fontRound:getWidth( RpgClasses[index].class )
			local px = x + 5
			if px + size > W then px = px - size end
   			love.graphics.setColor(255,255,255)
			love.graphics.rectangle("fill",px,y-20,size,theme.fontRound:getHeight())
   			love.graphics.setColor(0,0,0)
			love.graphics.print( RpgClasses[index].class , px, y-20 )
		else
			if snapshots[currentSnap].s[index].displayFilename then
			  local size = theme.fontRound:getWidth( snapshots[currentSnap].s[index].displayFilename )
			  local px = x + 5
			  if px + size > W then px = px - size end
   			  love.graphics.setColor(255,255,255)
			  love.graphics.rectangle("fill",px,y-20,size,theme.fontRound:getHeight())
   			  love.graphics.setColor(0,0,0)
			  love.graphics.print( snapshots[currentSnap].s[index].displayFilename, px, y-20 )
			end
		end
	end
   end

   self:drawResize()

end

function snapshotBar:update(dt)
	
	Window.update(self,dt)

  	local zx,zy = -( self.x - W / 2), -( self.y - H / 2)

	-- change snapshot offset if mouse  at bottom right or left
	local snapMax = #snapshots[currentSnap].s * (snapshotSize + snapshotMargin) - W
	if snapMax < 0 then snapMax = 0 end
	local x,y = love.mouse.getPosition()
	local left = math.max(zx,0)
	local right = math.min(zx+self.w,W)
	
	if x > left and x < right then

	  if (x < left + snapshotMargin * 4 ) and (y > zy) and (y < zy + self.h) then
	  	snapshots[currentSnap].offset = snapshots[currentSnap].offset + snapshotMargin * 2
	  	if snapshots[currentSnap].offset > 0 then snapshots[currentSnap].offset = 0  end
	  end

	  if (x > right - snapshotMargin * 4 ) and (y > zy) and (y < zy + self.h - iconSize) then
	  	snapshots[currentSnap].offset = snapshots[currentSnap].offset - snapshotMargin * 2
	  	if snapshots[currentSnap].offset < -snapMax then snapshots[currentSnap].offset = -snapMax end
	  end

	
	end
	end

function snapshotBar:click(x,y)

  local zx,zy = -( self.x * 1/self.mag - W / 2), -( self.y * 1/self.mag - H / 2)
  
  Window.click(self,x,y)
 
  if y > zy then mouseMove = false end -- Window.click() above might set mouseMove improperly
 
    --arrowMode = false
    -- check if there is a snapshot there
    local index = math.floor(((x-zx) - snapshots[currentSnap].offset) / ( snapshotSize + snapshotMargin)) + 1
    -- 2 possibilities: if this image is already selected, then use it
    -- otherwise, just select it (and deselect any other eventually)
    if index >= 1 and index <= #snapshots[currentSnap].s then

      -- this may start a drag&drop
      dragMove = true
      dragObject = { originWindow = self, snapshot = snapshots[currentSnap].s[index] }
      if currentSnap == 1 then dragObject.object = { class = "image" } end
      if currentSnap == 2 then dragObject.object = { class = "map" } end
      if currentSnap == 3 then dragObject.object = { class = "pnj", rpgClass = RpgClasses[index] } end
      if currentSnap == 4 then dragObject.object = { class = "pawn" } end

      if snapshots[currentSnap].s[index].selected then
	      -- already selected
	      snapshots[currentSnap].s[index].selected = false 

	      -- Three different ways to use a snapshot

	      -- 1: general image, sent it to projector
	      if currentSnap == 1 then
	      	pWindow.currentImage = snapshots[currentSnap].s[index].im
	      	-- remove the 'visible' flag from maps (eventually)
	      	atlas:removeVisible()
		tcpsend(projector,"ERAS") 	-- remove all pawns (if any) 
    	      	-- send the filename over the socket
		if snapshots[currentSnap].s[index].is_local then
			tcpsendBinary{ file = snapshots[currentSnap].s[index].file } 
 			tcpsend(projector,"BEOF")
		elseif fullBinary then
			tcpsendBinary{ filename = snapshots[currentSnap].s[index].filename } 
 			tcpsend(projector,"BEOF")
		else
	      		tcpsend( projector, "OPEN " .. snapshots[currentSnap].s[index].baseFilename)
		end
	      	tcpsend( projector, "DISP") 	-- display immediately

	      -- 2: map. This should open a window 
	      elseif currentSnap == 2 then

			layout:setDisplay( snapshots[currentSnap].s[index] , true )
			layout:setFocus( snapshots[currentSnap].s[index] ) 
	
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

-- insert a new message to display
function addMessage( text, time , important )
  if not time then time = 5 end
  table.insert( messages, { text=text , time=time, offset=0, important=important } )
end
 
-- send a command or data to the projector over the network
function tcpsend( tcp, data , verbose )
  if not tcp then return end -- no client connected yet !
  if verbose == nil or verbose == true then  
	local i,p=tcp:getpeername()
	io.write("send to " .. tostring(i) .. "," .. tostring(p) .. ":" .. data .. "\n") 
  end
  tcp:send(data .. "\n")
  end

-- send a whole binary file over the network
-- t is table with one (and only one) of file or filename
function tcpsendBinary( t )

 if not projector then return end 	-- no projector connected yet !
 local file = t.file
 local filename = t.filename
 assert( file or filename )

 tcpsend( projector, "BNRY") 		-- alert the projector that we are about to send a binary file
 local c = tcpbin:accept() 		-- wait for the projector to open a dedicated channel
 -- we send a given number of chunks in a row.
 -- At the end of file, we might send a smaller one, then nothing...
 if file then
 	file:open('r')
 	local data, size = file:read( chunksize )
 	while size ~= 0 do
       		c:send(data) -- send chunk
		io.write("sending " .. size .. " bytes. \n")
        	data, size = file:read( chunksize )
 	end
 else
  	file = assert( io.open( filename, 'rb' ) )
  	local data = file:read(chunksize)
 	while data do
       		c:send(data) -- send chunk
		io.write("sending " .. string.len(size) .. " bytes. \n")
        	data = file:read( chunksize )
 	end
 end
 file:close()
 c:close()
 end

-- capture text input (for text search)
function love.textinput(t)
	if (not searchActive) and (not textActiveCallback) then return end
	if ignoreLastChar then ignoreLastChar = false; return end
	if searchActive then
		text = text .. t
	else
		textActiveCallback( t )
	end
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

		local snap = Snapshot:new{ file = file }
		if is_a_pawn then 
			table.insert( snapshots[4].s , snap )
			snap.kind = "pawn"	
		else
			table.insert( snapshots[1].s , snap )
			snap.kind = "image"	
	  		-- set the local image
	  		pWindow.currentImage = snap.im 
			-- remove the 'visible' flag from maps (eventually)
			atlas:removeVisible()
		  	tcpsend(projector,"ERAS") 	-- remove all pawns (if any) 
			if not is_local and not fullBinary then
    	  	  		-- send the filename (without path) over the socket
		  		filename = string.gsub(filename,baseDirectory,"")
		  		tcpsend(projector,"OPEN " .. filename)
		  		tcpsend(projector,"DISP") 	-- display immediately
			elseif fullBinary then
		  		-- send the file itself...
		  		tcpsendBinary{ filename=filename } 
 				tcpsend(projector,"BEOF")
		  		tcpsend(projector,"DISP")
			else
		  		-- send the file itself...
		  		tcpsendBinary{ file=file } 
 				tcpsend(projector,"BEOF")
		  		tcpsend(projector,"DISP")
			end
		end

	  elseif is_a_map then  -- add map to the atlas
	    local m = Map:new()
	    m:load{ file=file, layout=layout } -- no filename, and file object means local 
	    --atlas:addMap( m )  
	    layout:addWindow( m , false )
	    table.insert( snapshots[2].s , m )

	  end

	end

-- GUI basic functions
function love.update(dt)

	-- decrease timelength of 1st message if any
--[[
	if messages[1] then 
	  if messages[1].time < 0 then
		messages[1].offset = messages[1].offset + 1
		if messages[1].offset > 21 then 
			table.remove( messages, 1 ) 
		end
	  else	  
		messages[1].time = messages[1].time - dt
	end	
	end
--]]

	-- update all windows
	layout:update(dt)

	-- all code below does not take place until the environement is fully initialized (ie baseDirectory is defined)
	if not initialized then return end

	-- listening to anyone calling on our port 
	local tcp = server:accept()
	if tcp then
		-- add it to the client list, we don't know who is it for the moment
		table.insert( clients , { tcp = tcp, id = nil } )
		local ad,ip = tcp:getpeername()
		addMessage("receiving connection from " .. tostring(ad) .. " " .. tostring(ip))
		io.write("receiving connection from " .. tostring(ad) .. " " .. tostring(ip) .. "\n")
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
	
	      elseif data == "CONNECTB" then 
		io.write("receiving projector call, binary mode\n")
		addMessage("Receiving projector call")
		addMessage("Projector is requesting full binary mode")
		fullBinary = true
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
		layout.dialogWindow:addLine(string.upper(data) .. " (" .. os.date("%X") .. ")" )
		--table.insert( dialogLog , string.upper(data) .. " (" .. os.date("%X") .. ")" )
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
		layout.dialogWindow:addLine(string.upper(clients[i].id) .. " : " .. string.upper(data) .. " (" .. os.date("%X") .. ")" )
		if ack then	
			tcpsend( clients[i].tcp, "(ack. " .. os.date("%X") .. ")" )
		end

	    else
		-- this is the projector

		-- allowed commands from projector are:
		--
		-- TARG id1 id2 	Pawn with id1 attacks pawn with id2
		-- MPAW id x y		Pawn with id moves to x,y in the map
		--

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
		  -- the two innocent lines below are important: x and y are returned as strings, not numbers, which is quite inocuous
		  -- except that tween() functions really expect numbers. Here we force x and y to be numbers.
		  x = x + 0
		  y = y + 0
		  for i=1,#map.pawns do 
			if map.pawns[i].id == id then 
				map.pawns[i].moveToX = x; map.pawns[i].moveToY = y; 
				pawnMaxLayer = pawnMaxLayer + 1
				map.pawns[i].layer = pawnMaxLayer
				map.pawns[i].timer = tween.new( pawnMovingTime , map.pawns[i] , { x = map.pawns[i].moveToX, y = map.pawns[i].moveToY } )
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

  	--view:update(dt)
  	--yui.update({view})


  	-- store current mouse position in arrow mode
  	if arrowMode then 
		arrowX, arrowY = love.mouse.getPosition() 
	end
  
	-- change pawn color to red if they are the target of an arrow
	if pawnMove then
		-- check that we are in the map...
		local map = layout:getFocus()
		if (not map) or (not map:isInside(arrowX,arrowY)) then return end
	
		-- check if we are just over another pawn
		local target = map:isInsidePawn(arrowX,arrowY)

		if target and target ~= pawnMove then
			-- we are targeting someone, draw the target in red color !
			target.color = theme.color.red
		end
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

  	-- draw dices if requested
	-- there are two phases of 1 second each: drawDices (all dices) then drawDicesResult (does not count failed ones)
  	if drawDices then

  		box:update(dt)

		if drawDicesKind == "d20" then
			if drawDicesTimer > 4 then
				-- reduce dice velocity, to stabilize it
				box[1].angular = vector{0,0,0}
				box[1].velocity[1] = 0.3 * box[1].velocity[1] 
				box[1].velocity[2] = 0.3 * box[1].velocity[2]
				box[1].velocity[3] = -1 
			end
		else
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

			local lastDiceSum = diceSum

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
 		end 

		-- dice are removed after a fixed timelength (30 sec.) or after the result is stable for long enough (6 sec.)
    		drawDicesTimer = drawDicesTimer + dt
		if drawDicesKind == "d20" then 
    			if drawDicesTimer >= 10 then drawDicesTimer = 0; drawDices = false; drawDicesResult = false; end
		else
			diceStableTimer = diceStableTimer + dt
    			if drawDicesTimer >= 30 or diceStableTimer >= 6 then drawDicesTimer = 0; drawDices = false; drawDicesResult = false; end
		end

  	end

	-- check PNJ-related timers
  	for i=1,#PNJTable do

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
      			PNJtext[i].init.color = theme.color.red
      			PNJTable[i].lastinit = PNJTable[i].lastinit + dt
      			if (PNJTable[i].lastinit >= 3) then
        			-- end of timing for this PNJ
        			PNJTable[i].initTimerLaunched = false
        			PNJTable[i].lastinit = 0
        			PNJtext[i].init.color = theme.color.darkblue
        			sortAndDisplayPNJ()
      			end
    		end

    		if (PNJTable[i].acceptDefLoss) then PNJtext[i].def.color = theme.color.darkblue else PNJtext[i].def.color = { 240, 10, 10 } end

  	end

  	-- change color of "Round" value after a certain amount of time (5 s.)
  	if (newRound) then
    		roundTimer = roundTimer + dt
    		if (roundTimer >= 5) then
      			view.s.t.round.color = theme.color.black
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


	end


-- draw a small colored circle, at position x,y, with 'id' as text
function drawRound( x, y, kind, id )
	if kind == "target" then love.graphics.setColor(250,80,80,180) end
  	if kind == "attacker" then love.graphics.setColor(204,102,0,180) end
  	if kind == "danger" then love.graphics.setColor(66,66,238,180) end 
  	love.graphics.circle ( "fill", x , y , 15 ) 
  	love.graphics.setColor(0,0,0)
  	love.graphics.setFont(theme.fontRound)
  	love.graphics.print ( id, x - string.len(id)*3 , y - 9 )
	end


function myStencilFunction( )
	local map = currentWindowDraw
	local x,y,mag,w,h = map.x, map.y, map.mag, map.w, map.h
        local zx,zy = -( x * 1/mag - W / 2), -( y * 1/mag - H / 2)
	love.graphics.rectangle("fill",zx,zy,w/mag,h/mag)
	for k,v in pairs(map.mask) do
		--local _,_,shape,x,y,wm,hm = string.find( v , "(%a+) (%d+) (%d+) (%d+) (%d+)" )
		local _,_,shape = string.find( v , "(%a+)" )
		if shape == "RECT" then 
			local _,_,_,x,y,wm,hm = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+) (%d+)" )
			x = zx + x/mag - map.translateQuadX/mag
			y = zy + y/mag - map.translateQuadY/mag
			love.graphics.rectangle( "fill", x, y, wm/mag, hm/mag) 
		elseif shape == "CIRC" then
			local _,_,_,x,y,r = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+%.?%d+)" )
			x = zx + x/mag - map.translateQuadX/mag
			y = zy + y/mag - map.translateQuadY/mag
			love.graphics.circle( "fill", x, y, r/mag ) 
		end
	end
	end

function love.draw() 

  local alpha = 80

  love.graphics.setColor(255,255,255)
  love.graphics.draw( theme.backgroundImage , 0, 0, 0, W / theme.backgroundImage:getWidth(), H / theme.backgroundImage:getHeight() )

  love.graphics.setLineWidth(2)

--[[
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
    

  end
--]]

  -- draw windows
  layout:draw() 

  -- all code below does not take place until the environement is fully initialized (ie baseDirectory is defined)
  if not initialized then return end

  -- drag & drop
  if dragMove then

	local x,y = love.mouse.getPosition()
	local s = dragObject.snapshot
	love.graphics.draw(s.im, x, y, 0, s.snapmag, s.snapmag)

  end

  -- draw arrow
  if arrowMode then

      -- draw arrow and arrow head
      love.graphics.setColor(unpack(theme.color.red))
      love.graphics.line( arrowStartX, arrowStartY, arrowX, arrowY )
      local x3, y3, x4, y4 = computeTriangle( arrowStartX, arrowStartY, arrowX, arrowY)
      if x3 then
        love.graphics.polygon( "fill", arrowX, arrowY, x3, y3, x4, y4 )
      end

      -- draw a pawn to know the size    
      if arrowPawn then
	local map = layout:getFocus()
	local w = distanceFrom(arrowX,arrowY,arrowStartX,arrowStartY)
	love.graphics.setColor(255,255,255,180)
	local s = defaultPawnSnapshot
	local f = w / s.im:getWidth() 
	love.graphics.draw( s.im, arrowStartX, arrowStartY, 0, f, f )
      end
 
      -- draw circle or rectangle itself
      if arrowModeMap == "RECT" then 
		love.graphics.rectangle("line",arrowStartX, arrowStartY,(arrowX - arrowStartX),(arrowY - arrowStartY)) 
      elseif arrowModeMap == "CIRC" then 
		love.graphics.circle("line",(arrowStartX+arrowX)/2, (arrowStartY+arrowY)/2, distanceFrom(arrowX,arrowY,arrowStartX,arrowStartY) / 2) 
      end
 
 end  

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
      love.graphics.setColor(unpack(theme.color.white))
      love.graphics.setFont(theme.fontDice)
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

	-- check if we must close the window
	local x,y = love.mouse.getPosition()
	local w = layout:getWindow(x,y)
	if w and w.markForClosure then 
		w.markForClosure = false
		layout:setDisplay(w,false) 
	end

	-- we were dragging, we drop the object
	if dragMove then
		dragMove = false
		if w then w:drop( dragObject ) end
	end

	-- we were moving or resizing the window. We stop now
	if mouseResize then 
		mouseResize = false
		mouseMove = false 
		-- we were resizing a map. Send the result to the projector eventually
		local window = layout:getFocus()
		if window and window.class == "map" and atlas:getVisible() == window then
  			tcpsend( projector, "MAGN " .. 1/window.mag)
  			tcpsend( projector, "CHXY " .. math.floor(window.x+window.translateQuadX) .. " " .. math.floor(window.y+window.translateQuadY) )
		end
		return 
	end
	if mouseMove then mouseMove = false; return end

	-- we were moving a pawn. we stop now
	if pawnMove then 

		arrowMode = false

		-- check that we are in the map, or in another map...
		local sourcemap = layout:getFocus()
		local targetmap = layout:getWindow( x , y )
		if (not targetmap) or (targetmap.class ~= "map") then pawnMove = nil; return end -- we are nowhere ! abort

		local map = targetmap

		--
		-- we are in another map: we just allow a move, not an attack
		--
		if map ~= sourcemap then

			-- if the target map has no pawn size already fixed, it is not easy to determine the right one
			-- here, we do a kind of ratio depending on the images respective widths
			local size = (sourcemap.basePawnSize / sourcemap.w) * map.w
			size = size / map.mag

			-- create the new pawn at 0,0, remove the old one
			local p = map:createPawns( 0, 0 , size , pawnMove.id ) -- size is ignored if map has pawns already...
			if p then
			
				sourcemap:removePawn( pawnMove.id )

				-- we consider that the mouse position is at the center of the new image
  				local zx,zy = -( map.x * 1/map.mag - W / 2), -( map.y * 1/map.mag - H / 2)
				local px, py = (x - zx) * map.mag - p.sizex / 2 , (y - zy) * map.mag - p.sizey / 2

				-- now it is created, set it to correct position
				p.x, p.y = px + map.translateQuadX, py + map.translateQuadY

				-- the pawn will popup, no tween
				pawnMaxLayer = pawnMaxLayer + 1
				pawnMove.layer = pawnMaxLayer
				table.sort( map.pawns , function (a,b) return a.layer < b.layer end )
	
				-- we must stay within the limits of the map	
				if p.x < 0 then p.x = 0 end
				if p.y < 0 then p.y = 0 end
				local w,h = map.w, map.h
				if map.quad then w,h = map.im:getDimensions() end
				if p.x + p.sizex + 6 > w then p.x = math.floor(w - p.sizex - 6) end
				if p.y + p.sizey + 6 > h then p.y = math.floor(h - p.sizey - 6) end
	
				if atlas:isVisible(sourcemap) then	
					tcpsend( projector , "ERAP " .. p.id )
					io.write("ERAP " .. p.id .. "\n")
				end

				if atlas:isVisible(map) then	

	  				local flag
	  				if p.PJ then flag = "1" else flag = "0" end
					local i = findPNJ( p.id )
	  				local f = p.snapshot.baseFilename -- FIXME: what about pawns loaded dynamically ?
	  				io.write("PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. 
						math.floor(p.sizex * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f .. "\n")
	  				tcpsend( projector, "PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. 
						math.floor(p.sizex * PNJTable[i].sizefactor) .. " " .. flag .. " " .. f)
				end

			end
		--
		-- we stay on same map: it may be a move or an attack
		--
		else

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
			pawnMove.moveToX, pawnMove.moveToY = (x - zx) * map.mag - pawnMove.sizex / 2 , (y - zy) * map.mag - pawnMove.sizey / 2
			pawnMove.moveToX = pawnMove.moveToX + map.translateQuadX
			pawnMove.moveToY = pawnMove.moveToY + map.translateQuadY
			
			pawnMaxLayer = pawnMaxLayer + 1
			pawnMove.layer = pawnMaxLayer
			table.sort( map.pawns , function (a,b) return a.layer < b.layer end )
	
			-- we must stay within the limits of the (unquad) map	
			if pawnMove.moveToX < 0 then pawnMove.moveToX = 0 end
			if pawnMove.moveToY < 0 then pawnMove.moveToY = 0 end
			local w,h = map.w, map.h
			if map.quad then w,h = map.im:getDimensions() end
			
			if pawnMove.moveToX + pawnMove.sizex + 6 > w then pawnMove.moveToX = math.floor(w - pawnMove.sizex - 6) end
			if pawnMove.moveToY + pawnMove.sizey + 6 > h then pawnMove.moveToY = math.floor(h - pawnMove.sizey - 6) end

			pawnMove.timer = tween.new( pawnMovingTime , pawnMove , { x = pawnMove.moveToX, y = pawnMove.moveToY } )
	
			tcpsend( projector, "MPAW " .. pawnMove.id .. " " ..  math.floor(pawnMove.moveToX) .. " " .. math.floor(pawnMove.moveToY) )		
			
		  end

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
		if map.basePawnSize then
			map:createPawns( arrowX, arrowY, w )
			table.sort( map.pawns, function(a,b) return a.layer < b.layer end )
		else
			map:setPawnSize(w)
		end
		arrowPawn = false
		return
	end

	-- if we were drawing a mask shape as well, we terminate it now (even if we are outside the map)
	if arrowModeMap and not arrowQuad then
	
		local map = layout:getFocus()
		assert( map and map.class == "map" )

	  	local command = nil

		local maxX, maxY, minX, minY = 0,0,0,0

	  	if arrowModeMap == "RECT" then

	  		if arrowStartX > arrowX then arrowStartX, arrowX = arrowX, arrowStartX end
	  		if arrowStartY > arrowY then arrowStartY, arrowY = arrowY, arrowStartY end
	  		local sx = math.floor( (arrowStartX + ( map.x / map.mag  - W / 2)) *map.mag )
	  		local sy = math.floor( (arrowStartY + ( map.y / map.mag  - H / 2)) *map.mag )
	  		local w = math.floor((arrowX - arrowStartX) * map.mag)
	  		local h = math.floor((arrowY - arrowStartY) * map.mag)

			-- if quad, apply current translation
			sx, sy = sx + map.translateQuadX, sy + map.translateQuadY

	  		command = "RECT " .. sx .. " " .. sy .. " " .. w .. " " .. h 
		
			maxX = sx + w
			minX = sx
			maxY = sy + h
			minY = sy
			if minX > maxX then minX, maxX = maxX, minX end
			if minY > maxY then minY, maxY = maxY, minY end

	  	elseif arrowModeMap == "CIRC" then

			local sx, sy = math.floor((arrowX + arrowStartX) / 2), math.floor((arrowY + arrowStartY) / 2)
	  		sx = math.floor( (sx + ( map.x / map.mag  - W / 2)) *map.mag )
	  		sy = math.floor( (sy + ( map.y / map.mag  - H / 2)) *map.mag )
			local r = distanceFrom( arrowX, arrowY, arrowStartX, arrowStartY) * map.mag / 2

			-- if quad, apply current translation
			sx, sy = sx + map.translateQuadX, sy + map.translateQuadY

	  		if r ~= 0 then command = "CIRC " .. sx .. " " .. sy .. " " .. r end

			maxX = sx + r
			minX = sx - r
			maxY = sy + r
			minY = sy - r
	  	end

	  	if command then 
			table.insert( map.mask , command ) 
			io.write("inserting new mask " .. command .. "\n")

			if minX < map.maskMinX then map.maskMinX = minX end
			if minY < map.maskMinY then map.maskMinY = minY end
			if maxX > map.maskMaxX then map.maskMaxX = maxX end
			if maxY > map.maskMaxY then map.maskMaxY = maxY end

	  		-- send over if requested
	  		if atlas:isVisible( map ) then tcpsend( projector, command ) end
	  	end

		arrowModeMap = nil
	
	elseif arrowQuad then
		-- drawing a Quad on a map
		local map = layout:getFocus()
		assert( map and map.class == "map" )
	
		map:setQuad(arrowStartX, arrowStartY, arrowX, arrowY)
	
      		-- this stops the arrow mode
      		arrowMode = false
		arrowQuad = false
		arrowModeMap = nil

	else 
		-- not drawing a mask, so maybe selecting a PNJ
	   	-- depending on position on y-axis
  	  	for i=1,#PNJTable do
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

	-- clicking somewhere in the map, this starts either a Move or a Mask	
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
	  		if not love.keyboard.isDown("lshift") and not love.keyboard.isDown("lctrl") 
				and not love.keyboard.isDown("lalt") then 
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
			elseif love.keyboard.isDown("lalt") then
				-- want to create a quad, but only if none already
				if not map.quad then
				  arrowMode = true
				  arrowQuad = true
	   			  arrowStartX, arrowStartY = x, y
	   			  mouseMove = false 
				  arrowModeMap = "RECT" 
				end
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

--[[
  -- Clicking on upper button section does not change the current FOCUS, but cancel the arrow
  if y < 40 then 
    arrowMode = false
    return
  end
--]]
 
end


Atlas = {}
Atlas.__index = Atlas

function Atlas:getScenario() return self.scenario end
function Atlas:removeVisible() self.visible = nil end
function Atlas:isVisible(map) return self.visible == map end
function Atlas:getVisible() return self.visible end 
function Atlas:toggleVisible( map )
	if not map then return end
	if map.kind == "scenario" then return end -- a scenario is never displayed to the players
	if self.visible == map then 
		self.visible = nil 
		map.sticky = false
		-- erase snapshot !
		pWindow.currentImage = nil 
	  	-- remove all pawns remotely !
		tcpsend( projector, "ERAS")
	  	-- send hide command to projector
		tcpsend( projector, "HIDE")
	else    
		self.visible = map 
		-- change snapshot !
		pWindow.currentImage = map.im
	  	-- remove all pawns remotely !
		tcpsend( projector, "ERAS")
		-- send to projector
		if map.is_local and not fullBinary then
		  tcpsendBinary{ file=map.file } 
 		  tcpsend(projector,"BEOF")
		elseif fullBinary then
		  tcpsendBinary{ filename=map.filename } 
 		  tcpsend(projector,"BEOF")
		else 
  		  tcpsend( projector, "OPEN " .. map.baseFilename )
		end
  		-- send mask if applicable
  		if map.mask then
			for k,v in pairs( map.mask ) do
				tcpsend( projector, v )
			end
  		end
		-- send pawns if any
		for i=1,#map.pawns do
			local p = map.pawns[i]
			-- check the pawn state before sending it: 
			-- * it might happen that the character has been removed from the list
			-- * don't send dead pawns (what for?)
			local index = findPNJ( p.id )
			if index and (not PNJTable[index].is_dead) then
				local flag = 0
				if p.PJ then flag = 1 end
				-- send over the socket
				if p.snapshot.is_local then
					tcpsendBinary{ file=p.snapshot.file }
	  				tcpsend( projector, "PEOF " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag )
				elseif fullBinary then
					tcpsendBinary{ filename=p.snapshot.filename }
	  				tcpsend( projector, "PEOF " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag )
				else
	  				local f = p.snapshot.filename
	  				f = string.gsub(f,baseDirectory,"")
	  				tcpsend( projector, "PAWN " .. p.id .. " " .. math.floor(p.x) .. " " .. math.floor(p.y) .. " " .. math.floor(p.sizex) .. " " .. flag .. " " .. f)
				end
			end
		end
		-- set map frame
  		tcpsend( projector, "MAGN " .. 1/map.mag)
  		tcpsend( projector, "CHXY " .. math.floor(map.x+map.translateQuadX) .. " " .. math.floor(map.y+map.translateQuadY) )
  		tcpsend( projector, "DISP")

	end
	end

function Atlas.new() 
  local new = {}
  setmetatable(new,Atlas)
  --new.maps = {}
  new.visible = nil -- map currently visible (or nil if none)
  new.scenario = nil -- reference the scenario window if any
  return new
  end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- return the index of the 1st character of a class, or nil if not found
function findPNJByClass( class )
  if not class then return nil end
  class = string.lower( trim(class) )
  for i=1,#PNJTable do if string.lower(PNJTable[i].class) == class then return i end end
  return nil
  end

function findClientByName( class )
  if not class then return nil end
  if not clients then return nil end
  class = string.lower( trim(class) )
  for i=1,#clients do if clients[i].id and string.lower(clients[i].id) == class then return clients[i].tcp end end
  return nil
  end

-- return the character by its ID, or nil if not found
function findPNJ( id )
  if not id then return nil end
  for i=1,#PNJTable do if PNJTable[i].id == id then return i end end
  return nil
  end

function love.mousemoved(x,y,dx,dy)

local w = layout:getFocus()
if not w then return end

if mouseResize then

	local zx,zy = w:WtoS(0,0)
	local mx,my = w:WtoS(w.w, w.h)

	-- check we are still within the window limits
	if x >= zx + 40 and y >= zy +40 then
		if w.whResizable then
		  assert(w.class == "map")
		  --local ratio = w.w / w.h
		  local projected = (x - mx)+(y - my)
		  local neww= w.w + projected * w.mag
		  local originalw, originalh = w.im:getDimensions()
		  if w.quad then _,_,originalw, originalh = w.quad:getViewport() end
		  local oldmag = originalw / w.w
		  local newmag = originalw / neww
		  if w.class == "map" then 
			w.mag = w.mag + (newmag - oldmag) 
			local cx,cy = w:WtoS(0,0)
			w:translate(zx-cx,zy-cy)
		  end
		else
		  if not w.wResizable then dx = 0 end
		  if not w.hResizable then dy = 0 end
		  w.w = w.w + dx * w.mag
		  w.h = w.h + dy * w.mag
		end
	end
 
elseif mouseMove then

	-- store old values, in case we need to rollback because we get outside limits
	local oldx, oldy = w.x, w.y

	-- check changes
	local newx = w.x - dx * w.mag 
	local newy = w.y - dy * w.mag 

	-- check we are still within margins of the screen
  	local zx,zy = -( newx * 1/w.mag - W / 2), -( newy * 1/w.mag - H / 2)
	
	if zx > W - screenMargin or zx + w.w / w.mag < screenMargin then newx = oldx end	
	if zy > H - screenMargin or zy + w.h / w.mag < screenMargin then newy = oldy end	

	local deltax, deltay = newx - oldx, newy - oldy

	-- move the map 
	if (newx ~= oldx or newy ~= oldy) then
		w:move( newx, newy )
		if w == storyWindow then actionWindow:move( actionWindow.x + deltax, actionWindow.y + deltay ) end
		if w == actionWindow then storyWindow:move( storyWindow.x + deltax, storyWindow.y + deltay ) end
	end

end

end

function love.keypressed( key, isrepeat )

if textActiveBackspaceCallback and key == "backspace" then textActiveBackspaceCallback(); return end
if textActiveLeftCallback and key == "left" then textActiveLeftCallback(); return end
if textActiveRightCallback and key == "right" then textActiveRightCallback(); return end
if textActivePasteCallback and key == "v" and love.keyboard.isDown(keyPaste) then textActivePasteCallback(); return end
if textActiveCopyCallback and key == "c" and love.keyboard.isDown(keyPaste) then textActiveCopyCallback(); return end

if not initialized then return end

-- keys applicable in any context
-- we expect:
-- 'lctrl + d' : open dialog window
-- 'lctrl + f' : open setup window
-- 'lctrl + h' : open help window
-- 'lctrl + tab' : give focus to the next window if any
-- 'escape' : hide or restore all windows 
if key == "d" and love.keyboard.isDown("lctrl") then
  layout:toggleWindow( layout.dialogWindow )
  return
end
if key == "h" and love.keyboard.isDown("lctrl") then 
  layout:toggleWindow( layout.helpWindow )
  return
end
if key == "f" and love.keyboard.isDown("lctrl") then 
  layout:toggleWindow( layout.dataWindow )
  return
end
if key == "escape" then
	layout:toggleDisplay()
	return
end
if key == "tab" and love.keyboard.isDown("lctrl") then
	layout:nextWindow()
	return
end
if key == "r" and love.keyboard.isDown("lctrl") then
	if actionWindow.open then
		layout:hideAll()	
		layout:restoreBase(layout.pWindow)
		layout:restoreBase(layout.snapshotWindow)
		layout:restoreBase(layout.combatWindow)
	elseif storyWindow.open then
		layout:hideAll()	
		layout:restoreBase(layout.pWindow)
		layout:restoreBase(layout.snapshotWindow)
		layout:restoreBase(layout.scenarioWindow)
	end
end

-- other keys applicable 
local window = layout:getFocus()
if not window then
  -- no window selected at the moment, we expect:
  -- FIXME: do we expect something ?
 
else
  -- a window is selected. Keys applicable to any window:
  -- 'lctrl + c' : recenter window
  -- 'lctrl + x' : close window
  if key == "x" and love.keyboard.isDown("lctrl") then
	layout:setDisplay( window, false )
	return
  end
  if key == "c" and love.keyboard.isDown("lctrl") then
	window:move( window.w / 2, window.h / 2 )
	return
  end

  if     window.class == "dialog" then
	-- 'return' to submit a dialog message
	-- 'backspace'
	-- any other key is treated as a message input
  	if (key == "return") then
	  --doDialog( string.gsub( dialog, dialogBase, "" , 1) )
	  --dialog = dialogBase
	  doDialog()
  	end
--[[
  	if (key == "backspace") and (dialog ~= dialogBase) then
         -- get the byte offset to the last UTF-8 character in the string.
         local byteoffset = utf8.offset(dialog, -1)
         if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            dialog = string.sub(dialog, 1, byteoffset - 1)
         end
  	end
--]]
	
  elseif window.class == "snapshot" then
  
  	-- 'space' to change snapshot list
	if key == 'space' then
	  currentSnap = currentSnap + 1
	  if currentSnap == 5 then currentSnap = 1 end
	  window:setTitle( snapText[currentSnap] ) 
	  return
  	end

  elseif window.class == "combat" then
  
  	-- 'up', 'down' within the PNJ list
  	if focus and key == "down" then
    		if focus < #PNJTable then 
      			lastFocus = focus
      			focus = focus + 1
      			focusAttackers = PNJTable[ focus ].attackers
      			focusTarget  = PNJTable[ focus ].target
    		end
    		return
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

  elseif window.class == "map" and window.kind == "map" then

	local map = window

	-- keys for map. We expect:
	-- Zoom in and out
	-- 'tab' to get to circ or rect mode
	-- 'lctrl + p' : remove all pawns
	-- 'lctrl + v' : toggle visible / not visible
	-- 'lctrl + z' : maximize/minimize (zoom)
	-- 'lctrl + s' : stick map
	-- 'lctrl + u' : unstick map

  	if key == "s" and love.keyboard.isDown("lctrl") then
		if not atlas:isVisible(map) then return end -- if map is not visible, do nothing
		if not map.sticky then
			-- we enter sticky mode. Normally, the projector is fully aligned already, so
			-- we just save the current status for future restoration
			map.stickX, map.stickY, map.stickmag = map.x, map.y, map.mag
			map.sticky = true
		else
			-- we were already sticky, with a different status probably. So we store this
			-- new one, but we need to align the projector as well
			map.stickX, map.stickY, map.stickmag = map.x, map.y, map.mag
			tcpsend( projector, "CHXY " .. math.floor(map.x+map.translateQuadX) .. " " .. math.floor(map.y+map.translateQuadY) ) 
			tcpsend( projector, "MAGN " .. 1/map.mag ) 
		end
		return
  	end

  	if key == "u" and love.keyboard.isDown("lctrl") then
		if not map.sticky then return end
		window:move( window.stickX , window.stickY )
		window.mag = window.stickmag
		window.sticky = false
		return
	end

    	if key == keyZoomIn then
		ignoreLastChar = true
		map:zoom( 1 )
    	end 

    	if key == keyZoomOut then
		ignoreLastChar = true
		map:zoom( -1 )
    	end 
    
	if key == "v" and love.keyboard.isDown("lctrl") then
		atlas:toggleVisible( map )
		if not atlas:isVisible( map ) then map.sticky = false end
    	end

   	if key == "p" and love.keyboard.isDown("lctrl") then
	   map.pawns = {} 
	   map.basePawnSize = nil
	   tcpsend( projector, "ERAS" )    
   	end
   	if key == "z" and love.keyboard.isDown("lctrl") then
		map:maximize()
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
	-- 'lctrl + z' : maximize/minimize (zoom)
	-- any other key is treated as a search query input
    	if key == keyZoomIn then
		ignoreLastChar = true
		map:zoom( 1 )
    	end 

    	if key == keyZoomOut then
		ignoreLastChar = true
		map:zoom( -1 )
    	end 
	
   	if key == "z" and love.keyboard.isDown("lctrl") then
		map:maximize()
	end

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
	  if searchIterator then map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator() end
   	end

   	if key == "return" then
	  searchIterator = doSearch( string.gsub( text, textBase, "" , 1) )
	  text = textBase
	  if searchIterator then map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator() end
   	end

  end
  end

  end


function leave()
	if server then server:close() end
	for i=1,#clients do clients[i].tcp:close() end
	if tcpbin then tcpbin:close() end
	if logFile then logFile:close() end
	end

-- load initial data from file at startup
function parseDirectory( t )

    -- call with kind == "all" or "pawn", and path
    local path = assert(t.path)
    local kind = t.kind or "all"

    -- list all files in that directory, by executing a command ls or dir
    local allfiles = {}, command
    if love.system.getOS() == "OS X" then
	    io.write("ls '" .. path .. "' > .temp\n")
	    os.execute("ls '" .. path .. "' > .temp")
    elseif love.system.getOS() == "Windows" then
	    io.write("dir /b \"" .. path .. "\" > .temp\n")
	    os.execute("dir /b \"" .. path .. "\" > .temp ")
    end

    -- store output
    for line in io.lines (".temp") do table.insert(allfiles,line) end

    -- remove temporary file
    os.remove (".temp")

    for k,f in pairs(allfiles) do

      io.write("scanning file '" .. f .. "\n")

      if kind == "pawns" then

	-- all (image) files are considered as pawn images
	if string.sub(f,-4) == '.jpg' or string.sub(f,-4) == '.png'  then

		local s = Snapshot:new{ filename = path .. sep .. f }
		local store = true

        	if string.sub(f,1,4) == 'pawn' then
		-- check if corresponds to a known PJ. In that case, do not
		-- store it in the snapshot list, as it is supposed to be unique
			local pjname = string.sub(f,5, f:len() - 4 )
			io.write("Looking for a PJ named " .. pjname .. "\n")
			local index = findPNJByClass( pjname ) 
			if index then 
				PNJTable[index].snapshot = s  
				store = false
			end
		end	
   
		if store then table.insert( snapshots[4].s, s ) end

		-- check if default image 
      		if f == 'pawnDefault.jpg' then
			defaultPawnSnapshot = s 
		end

		-- check if corresponds to a PNJ template as well
		for i=1,#RpgClasses do
			if RpgClasses[i].image == f then 
				RpgClasses[i].snapshot = s 
				io.write("store image for class " .. RpgClasses[i].class .. "\n")
			end
		end

	end
 
      elseif f == 'scenario.txt' then 

      	--   SCENARIO IMAGE: 	named scenario.jpg
      	--   SCENARIO TEXT:	associated to this image, named scenario.txt
      	--   MAPS: 		map*jpg or map*png, they are considered as maps and loaded as such
      	--   PJ IMAGE:		pawnPJname.jpg or .png, they are considered as images for corresponding PJ
      	--   PNJ DEFAULT IMAGE:	pawnDefault.jpg
      	--   PAWN IMAGE:		pawn*.jpg or .png
      	--   SNAPSHOTS:		*.jpg or *.png, all are snapshots displayed at the bottom part

	      readScenario( path .. sep .. f ) 
	      io.write("Loaded scenario at " .. path .. sep .. f .. "\n")

      elseif f == 'scenario.jpg' then

	local s = Map:new()
	s:load{ kind="scenario", filename=path .. sep .. f , layout=layout}
	layout:addWindow( s , false )
	atlas.scenario = s
	io.write("Loaded scenario image file at " .. path .. sep .. f .. "\n")
	--table.insert( snapshots[2].s, s )  -- don't insert in snapshots anymore

      elseif f == 'pawnDefault.jpg' then

	defaultPawnSnapshot = Snapshot:new{ filename = path .. sep .. f }
	table.insert( snapshots[4].s, defaultPawnSnapshot ) 

      elseif string.sub(f,-4) == '.jpg' or string.sub(f,-4) == '.png'  then

        if string.sub(f,1,4) == 'pawn' then

		local s = Snapshot:new{ filename = path .. sep .. f }
		table.insert( snapshots[4].s, s ) 
		
		local pjname = string.sub(f,5, f:len() - 4 )
		io.write("Looking for PJ " .. pjname .. "\n")
		local index = findPNJByClass( pjname ) 
		if index then PNJTable[index].snapshot = s  end

	elseif string.sub(f,1,3) == 'map' then

	  local s = Map:new()
	  s:load{ filename=path .. sep .. f , layout=layout} 
	  layout:addWindow( s , false )
	  table.insert( snapshots[2].s, s ) 

 	else
	  
	  local s = Snapshot:new{ filename = path .. sep .. f } 
	  table.insert( snapshots[1].s, s ) 
	  
        end

      end

    end

    -- all classes are loaded with a snapshot
    -- add them to snapshotBar
    for i=1,#RpgClasses do
	if not RpgClasses[i].snapshot then RpgClasses[i].snapshot = defaultPawnSnapshot end
	if not RpgClasses[i].PJ then table.insert( snapshots[3].s, RpgClasses[i].snapshot ) end
    end

    
end


function init() 

    io.write("base directory   : " .. baseDirectory .. "\n") ; addMessage("base directory : " .. baseDirectory .. "\n")
    io.write("scenario directory : " .. fadingDirectory .. "\n") ; addMessage("scenario : " .. fadingDirectory .. "\n")

    -- create socket and listen to any client
    server = socket.tcp()
    server:settimeout(0)
    local success, msg = server:bind(address, serverport)
    io.write("server local bind to " .. tostring(address) .. ":" .. tostring(serverport) .. ":" .. tostring(success) .. "," .. tostring(msg) .. "\n")
    if not success then leave(); love.event.quit() end
    server:listen(10)

    tcpbin = socket.tcp()
    tcpbin:bind(address, serverport+1)
    tcpbin:listen(1)

    -- initialize class template list  and dropdown list (opt{}) at the same time
    -- later on, we might attach some images to these classes if we find them
    -- try 2 locations to find data. Merge results if 2 files 
    opt, RpgClasses = loadClasses{ baseDirectory .. sep .. "data" , 
				   baseDirectory .. sep .. fadingDirectory .. sep .. "data" } 

    if not opt or #opt == 0 then error("sorry, need at least one data file") end

    local current_class = opt[1]


    -- create view structure
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
                yui.Button({text=" Create ", size=size, 
			onClick = function(self) return generateNewPNJ(current_class) and sortAndDisplayPNJ() end }),
                yui.HorizontalSpacing({w=50}),
                yui.Button({name = "rollatt", text="     Roll Attack     ", size=size, black = true,
			onClick = function(self) if self.button.black then return end rollAttack("attack") end }), 
		yui.HorizontalSpacing({w=10}),
                yui.Button({name = "rollarm", text="     Roll  Armor     ", size=size, black = true,
			onClick = function(self) if self.button.black then return end rollAttack("armor") end }),
                yui.HorizontalSpacing({w=150}),
                yui.Button({name="cleanup", text="       Cleanup       ", size=size, 
			onClick = function(self) return removeDeadPNJ() and sortAndDisplayPNJ() end }),
                --yui.HorizontalSpacing({w=270}),
                --yui.Button({text="    Quit    ", size=size, onClick = function(self) leave(); love.event.quit() end }),
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
    
    -- create PJ automatically (1 instance of each!)
    -- later on, an image might be attached to them, if we find one
    createPJ()

    -- create a new empty atlas (an array of maps)
    atlas = Atlas.new()

    -- load various data files
    parseDirectory{ path = baseDirectory .. sep .. fadingDirectory }
    parseDirectory{ path = baseDirectory .. sep .. "pawns" , kind = "pawns" }

    -- create basic windows
    combatWindow = Combat:new{ w=WC, h=HC, x=Window:cx(intW), y=Window:cy(intW),layout=layout}
    pWindow = projectorWindow:new{ w=layout.W1, h=layout.H1, x=Window:cx(WC+intW+3),y=Window:cy(H - 3*iconSize - snapshotSize - 2*intW - layout.H1 - 2 ) ,layout=layout}
    snapshotWindow = snapshotBar:new{ w=W-2*intW, h=snapshotSize+2, x=Window:cx(intW), y=Window:cy(H-snapshotSize-2*iconSize),layout=layout }
    storyWindow = iconWindow:new{ mag=2.1, text = "L'Histoire", image = theme.storyImage, w=theme.storyImage:getWidth(), 
				  h=theme.storyImage:getHeight() , x=-1220, y=400,layout=layout}
    actionWindow = iconWindow:new{ mag=2.1, text = "L'Action", image = theme.actionImage, w=theme.actionImage:getWidth(), 
				   h=theme.actionImage:getHeight(), x=-1220,y=700,layout=layout} 
    rollWindow = iconRollWindow:new{ mag=3.5, image = theme.dicesImage, w=theme.dicesImage:getWidth(), h=theme.dicesImage:getHeight(), x=-2074,y=133,layout=layout} 
    notifWindow = notificationWindow:new{ w=300, h=100, x=-W/2,y=H/2-50,layout=layout, messages=messages } 
    dialogWindow = Dialog:new{w=800,h=220,x=400,y=110,layout=layout}
    helpWindow = Help:new{w=1000,h=480,x=500,y=240,layout=layout}
    dataWindow = setupWindow:new{ w=600, h=400, x=300,y=H/2-100, init=true,layout=layout} 

    -- do not display them yet
    -- basic windows (as opposed to maps, for instance) are also stored by name, so we can retrieve them easily elsewhere in the code
    layout:addWindow( combatWindow , false, "combatWindow" ) 
    layout:addWindow( pWindow , false, "pWindow" )
    layout:addWindow( snapshotWindow , false , "snapshotWindow" )
    layout:addWindow( notifWindow , false , "notifWindow" )
    layout:addWindow( dialogWindow , false , "dialogWindow" )
    layout:addWindow( helpWindow , false , "helpWindow" ) 
    layout:addWindow( dataWindow , false , "dataWindow" )

    layout:addWindow( storyWindow , true , "storyWindow" )
    layout:addWindow( actionWindow , true , "actionWindow" )
    layout:addWindow( rollWindow , true , "rollWindow" )

    -- check if we have a scenario loaded. Reference it for direct access. Update size and mag factor to fit screen
    scenarioWindow = atlas:getScenario()
    if scenarioWindow then
      layout.scenarioWindow = scenarioWindow
      local w,h = scenarioWindow.w, scenarioWindow.h
      local f1,f2 = w/WC, h/HC
      scenarioWindow.mag = math.max(f1,f2)
      scenarioWindow.x, scenarioWindow.y = scenarioWindow.w/2, scenarioWindow.h/2
      local zx,zy = scenarioWindow:WtoS(0,0)
      scenarioWindow:translate(0,intW+iconSize-zy)
      scenarioWindow.startupX, scenarioWindow.startupY, scenarioWindow.startupMag = scenarioWindow.x, scenarioWindow.y, scenarioWindow.mag
    end

 
end


--
-- Main function
-- Load PNJ class file, print (empty) GUI, then go on
--
function love.load( args )

    -- load config file
    dofile( "fading2/fsconf.lua" )    

    -- GUI initializations...
    love.window.setTitle( "Fading Suns Tabletop" )
    love.keyboard.setKeyRepeat(true)
    yui.UI.registerEvents()

--[[
    -- load fonts
    fontTitle 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",20)
    fontDice 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",90)
    fontRound 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",12)
    fontSearch 		= love.graphics.newFont("yui/yaoui/fonts/georgia.ttf",16)
   
    -- base images
    backgroundImage 	= love.graphics.newImage( "images/background.jpg" )
    actionImage 	= love.graphics.newImage( "images/action.jpg" )
    storyImage 		= love.graphics.newImage( "images/histoire.jpg" )
    dicesImage 		= love.graphics.newImage( "images/dices.png" )

    -- base icons. We expect 16x16 icons
    iconClose 		= love.graphics.newImage( "icons/close16x16red.png" )
    iconResize 		= love.graphics.newImage( "icons/minimize16x16.png" )
    iconOnTopInactive 	= love.graphics.newImage( "icons/ontop16x16black.png" )
    iconOnTopActive 	= love.graphics.newImage( "icons/ontop16x16red.png" )
    iconReduce	 	= love.graphics.newImage( "icons/reduce16x16.png" )
    iconExpand	 	= love.graphics.newImage( "icons/expand16x16.png" )
--]]

    -- some adjustments on different systems
    if love.system.getOS() == "Windows" then
	keyZoomIn, keyZoomOut = ':', '!'
    	sep = '\\'
	keyPaste = 'lctrl'
    end

    -- get actual screen size
    love.window.setMode( 0  , 0  , { fullscreen=false, resizable=true, display=1} )
    love.window.maximize()
    W, H = love.window.getMode()
    io.write("W,H=" .. W .. " " .. H .. "\n")

    -- adjust some windows accordingly
    messagesH	= H 
    snapshotH = messagesH - snapshotSize - snapshotMargin
    HC = H - 4 * intW - 3 * iconSize - snapshotSize
    WC = 1290 - 2 * intW
    viewh = HC 		-- view height
    vieww = W - 260	-- view width

    -- some initialization stuff
    generateUID = UIDiterator()

    -- launch further init procedure if possible or display setup window to require mandatory information. 
    if baseDirectory and baseDirectory ~= "" then
      init()
      initialized = true
    else
      dataWindow = setupWindow:new{ w=600, h=400, x=300,y=H/2-100, init=false,layout=layout} 
      layout:addWindow( dataWindow , true, "dataWindow" )
      initialized = false
    end

    end

