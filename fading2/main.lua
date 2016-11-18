
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
local snapshotBar		= require 'snapshot'		-- all kinds of images 
local Map			= require 'map'			-- maps 
local Combat			= require 'combat'		-- main combat window (with PNJ list) 

-- specific object classes
local Snapshot			= require 'snapshotClass'	-- store and display one image 
local Pawn			= require 'pawn'		-- store and display one pawn to display on map 
local Atlas			= require 'atlas'		-- store some information on maps (eg. which one is visible) 

layout = mainLayout:new()		-- one instance of the global layout, FIXME: cannot be local for the moment because of yui library
local atlas = nil 			-- will be set in init()

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
--W, H = 1440, 800 	-- main window size default values (may be changed dynamically on some systems)
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

-- projector snapshot size
layout.H1, layout.W1 	= 140, 140
layout.snapshotSize 	= 70 			-- w and h of each snapshot
layout.screenMargin 	= 40			-- screen margin in map mode

snapshotMargin 		= 7 				-- space between images and screen border

size = 19 		-- base font size

-- various mouse movements
mouseMove		= false
dragMove		= false
dragObject		= { originWindow = nil, object = nil, snapshot = nil }

-- pawns and PJ snapshots
pawnMove 		= nil		-- pawn currently moved by mouse movement
defaultPawnSnapshot	= nil		-- default image to be used for pawns
pawnMaxLayer		= 1
pawnMovingTime		= 2		-- how many seconds to complete a movement on the map ?

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

-- we write only in debug mode
local oldiowrite = io.write
function io.write( data ) if debug then oldiowrite( data ) end end

function splitFilename(strFilename)
	--return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
	return string.match (strFilename,"[^/]+$")
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

		local snap = Snapshot:new{ file = file, size=layout.snapshotSize }
		if is_a_pawn then 
			table.insert( layout.snapshotWindow.snapshots[4].s , snap )
			snap.kind = "pawn"	
		else
			table.insert( layout.snapshotWindow.snapshots[1].s , snap )
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

	  elseif is_a_map then 
	    local m = Map:new()
	    m:load{ file=file, layout=layout, atlas=atlas } -- no filename, and file object means local 
	    layout:addWindow( m , false )
	    table.insert( layout.snapshotWindow.snapshots[2].s , m )

	  end

	end

-- GUI basic functions
function love.update(dt)

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
		layout.notificationWindow:addMessage("receiving connection from " .. tostring(ad) .. " " .. tostring(ip))
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
		layout.notificationWindow:addMessage("receiving projector call")
		clients[i].id = projectorId
		projector = clients[i].tcp
	    	tcpsend(projector,"CONN")
	
	      elseif data == "CONNECTB" then 
		io.write("receiving projector call, binary mode\n")
		layout.notificationWindow:addMessage("Receiving projector call")
		layout.notificationWindow:addMessage("Projector is requesting full binary mode")
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
		layout.notificationWindow:addMessage( string.upper(data) , 8 , true ) 
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
		layout.notificationWindow:addMessage( string.upper(clients[i].id) .. " : " .. string.upper(data) , 8 , true ) 
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
		  rpg.updateTargetByArrow( indexP, indexT )
		  layout.combatWindow:setFocus(indexP)
		  --layout.combatWindow:updateLineColor(indexP)
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
        local zx,zy = -( x * 1/mag - layout.W / 2), -( y * 1/mag - layout.H / 2)
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
  love.graphics.draw( theme.backgroundImage , 0, 0, 0, layout.W / theme.backgroundImage:getWidth(), layout.H / theme.backgroundImage:getHeight() )

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
  				local zx,zy = -( map.x * 1/map.mag - layout.W / 2), -( map.y * 1/map.mag - layout.H / 2)
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
			rpg.updateTargetByArrow( indexP, indexT )
		  	layout.combatWindow:setFocus(indexP)
		  	--layout.combatWindow:updateLineColor(indexP)
			
		  else

			-- it was just a move, change the pawn position
			-- we consider that the mouse position is at the center of the new image
  			local zx,zy = -( map.x * 1/map.mag - layout.W / 2), -( map.y * 1/map.mag - layout.H / 2)
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
	  		local sx = math.floor( (arrowStartX + ( map.x / map.mag  - layout.W / 2)) *map.mag )
	  		local sy = math.floor( (arrowStartY + ( map.y / map.mag  - layout.H / 2)) *map.mag )
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
	  		sx = math.floor( (sx + ( map.x / map.mag  - layout.W / 2)) *map.mag )
	  		sy = math.floor( (sy + ( map.y / map.mag  - layout.H / 2)) *map.mag )
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
        			rpg.updateTargetByArrow(arrowStartIndex, arrowStopIndex) 
		  		layout.combatWindow:setFocus(arrowStartIndex)
		  		--layout.combatWindow:updateLineColor(arrowStartIndex)

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
  	local zx,zy = -( newx * 1/w.mag - layout.W / 2), -( newy * 1/w.mag - layout.H / 2)
	
	if zx > layout.W - layout.screenMargin or zx + w.w / w.mag < layout.screenMargin then newx = oldx end	
	if zy > layout.H - layout.screenMargin or zy + w.h / w.mag < layout.screenMargin then newy = oldy end	

	local deltax, deltay = newx - oldx, newy - oldy

	-- move the map 
	if (newx ~= oldx or newy ~= oldy) then
		w:move( newx, newy )
		if w == layout.storyWindow then layout.actionWindow:move( layout.actionWindow.x + deltax, layout.actionWindow.y + deltay ) end
		if w == layout.actionWindow then layout.storyWindow:move( layout.storyWindow.x + deltax, layout.storyWindow.y + deltay ) end
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
	
  elseif window.class == "snapshot" then
  
  	-- 'space' to change snapshot list
	if key == 'space' then
	  window.currentSnap = window.currentSnap + 1
	  if window.currentSnap == 5 then window.currentSnap = 1 end
	  window:setTitle( window.snapText[window.currentSnap] ) 
	  return
  	end

  elseif window.class == "combat" then
 
  	-- 'up', 'down' within the PNJ list
  	if window.focus and key == "down" then
    		if window.focus < #PNJTable then 
      			window.lastFocus = window.focus
      			window.focus = window.focus+1
      			window.focusAttackers = PNJTable[ window.focus ].attackers
      			window.focusTarget  = PNJTable[ window.focus ].target
    		end
    		return
  	end
  
  	if window.focus and key == "up" then
    		if window.focus > 1 then 
      			window.lastFocus = window.focus
      			window.focus = window.focus - 1
      			window.focusAttackers = PNJTable[ window.focus ].attackers
      			window.focusTarget  = PNJTable[ window.focus ].target
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

		local s = Snapshot:new{ filename = path .. sep .. f, size=layout.snapshotSize }
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
   
		if store then table.insert( layout.snapshotWindow.snapshots[4].s, s ) end

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
	s:load{ kind="scenario", filename=path .. sep .. f , layout=layout, atlas=atlas}
	layout:addWindow( s , false )
	atlas.scenario = s
	io.write("Loaded scenario image file at " .. path .. sep .. f .. "\n")
	--table.insert( snapshots[2].s, s )  -- don't insert in snapshots anymore

      elseif f == 'pawnDefault.jpg' then

	defaultPawnSnapshot = Snapshot:new{ filename = path .. sep .. f , size=layout.snapshotSize }
	table.insert( layout.snapshotWindow.snapshots[4].s, defaultPawnSnapshot ) 

      elseif string.sub(f,-4) == '.jpg' or string.sub(f,-4) == '.png'  then

        if string.sub(f,1,4) == 'pawn' then

		local s = Snapshot:new{ filename = path .. sep .. f , size=layout.snapshotSize }
		table.insert( layout.snapshotWindow.snapshots[4].s, s ) 
		
		local pjname = string.sub(f,5, f:len() - 4 )
		io.write("Looking for PJ " .. pjname .. "\n")
		local index = findPNJByClass( pjname ) 
		if index then PNJTable[index].snapshot = s  end

	elseif string.sub(f,1,3) == 'map' then

	  local s = Map:new()
	  s:load{ filename=path .. sep .. f , layout=layout, atlas=atlas} 
	  layout:addWindow( s , false )
	  table.insert( layout.snapshotWindow.snapshots[2].s, s ) 

 	else
	  
	  local s = Snapshot:new{ filename = path .. sep .. f , size=layout.snapshotSize } 
	  table.insert( layout.snapshotWindow.snapshots[1].s, s ) 
	  
        end

      end

    end

    -- all classes are loaded with a snapshot
    -- add them to snapshotBar
    for i=1,#RpgClasses do
	if not RpgClasses[i].snapshot then RpgClasses[i].snapshot = defaultPawnSnapshot end
	if not RpgClasses[i].PJ then table.insert( layout.snapshotWindow.snapshots[3].s, RpgClasses[i].snapshot ) end
    end

    
end


function init() 

    -- create basic windows
    combatWindow = Combat:new{ w=layout.WC, h=layout.HC, x=-intW+layout.W/2, y=-intW+layout.H/2-theme.iconSize,layout=layout}

    pWindow = projectorWindow:new{ w=layout.W1, h=layout.H1, x=-(layout.WC+intW+3)+layout.W/2,
					y=-(layout.H - 3*iconSize - layout.snapshotSize - 2*intW - layout.H1 - 2 )+layout.H/2 - theme.iconSize ,layout=layout}

    snapshotWindow = snapshotBar:new{ w=layout.W-2*intW, h=layout.snapshotSize+2, x=-intW+layout.W/2, 
					y=-(layout.H-layout.snapshotSize-2*iconSize)+layout.H/2 - theme.iconSize ,layout=layout, atlas=atlas }

    storyWindow = iconWindow:new{ mag=2.1, text = "L'Histoire", image = theme.storyImage, w=theme.storyImage:getWidth(), 
				  h=theme.storyImage:getHeight() , x=-1220, y=400,layout=layout}

    actionWindow = iconWindow:new{ mag=2.1, text = "L'Action", image = theme.actionImage, w=theme.actionImage:getWidth(), 
				   h=theme.actionImage:getHeight(), x=-1220,y=700,layout=layout} 

    rollWindow = iconRollWindow:new{ mag=3.5, image = theme.dicesImage, w=theme.dicesImage:getWidth(), h=theme.dicesImage:getHeight(), x=-2074,y=133,layout=layout} 

    notifWindow = notificationWindow:new{ w=300, h=100, x=-layout.W/2,y=layout.H/2-50,layout=layout } 

    dialogWindow = Dialog:new{w=800,h=220,x=400,y=110,layout=layout}

    helpWindow = Help:new{w=1000,h=480,x=500,y=240,layout=layout}

    dataWindow = setupWindow:new{ w=600, h=400, x=300,y=layout.H/2-100, init=true,layout=layout} 

    -- do not display them yet
    -- basic windows (as opposed to maps, for instance) are also stored by name, so we can retrieve them easily elsewhere in the code
    layout:addWindow( combatWindow , false, "combatWindow" ) 
    layout:addWindow( pWindow , false, "pWindow" )
    layout:addWindow( snapshotWindow , false , "snapshotWindow" )
    layout:addWindow( notifWindow , false , "notificationWindow" )
    layout:addWindow( dialogWindow , false , "dialogWindow" )
    layout:addWindow( helpWindow , false , "helpWindow" ) 
    layout:addWindow( dataWindow , false , "dataWindow" )

    layout:addWindow( storyWindow , true , "storyWindow" )
    layout:addWindow( actionWindow , true , "actionWindow" )
    layout:addWindow( rollWindow , true , "rollWindow" )

    io.write("base directory   : " .. baseDirectory .. "\n") ; layout.notificationWindow:addMessage("base directory : " .. baseDirectory .. "\n")
    io.write("scenario directory : " .. fadingDirectory .. "\n") ; layout.notificationWindow:addMessage("scenario : " .. fadingDirectory .. "\n")

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
    _, RpgClasses = rpg.loadClasses{ 	baseDirectory .. sep .. "data" , 
			         	baseDirectory .. sep .. fadingDirectory .. sep .. "data" } 

    if not RpgClasses or #RpgClasses == 0 then error("sorry, need at least one data file") end

    -- create PJ automatically (1 instance of each!)
    -- later on, an image might be attached to them, if we find one
    rpg.createPJ()
    layout.combatWindow:sortAndDisplayPNJ()

    -- create a new empty atlas (an array of maps), and tell him where to project
    atlas = Atlas.new( layout.pWindow )

    -- load various data files
    parseDirectory{ path = baseDirectory .. sep .. fadingDirectory }
    parseDirectory{ path = baseDirectory .. sep .. "pawns" , kind = "pawns" }

    -- check if we have a scenario loaded. Reference it for direct access. Update size and mag factor to fit screen
    scenarioWindow = atlas:getScenario()
    if scenarioWindow then
      layout.scenarioWindow = scenarioWindow
      local w,h = scenarioWindow.w, scenarioWindow.h
      local f1,f2 = w/layout.WC, h/layout.HC
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

    -- some adjustments on different systems
    if love.system.getOS() == "Windows" then
	keyZoomIn, keyZoomOut = ':', '!'
    	sep = '\\'
	keyPaste = 'lctrl'
    end

    -- get actual screen size
    love.window.setMode( 0  , 0  , { fullscreen=false, resizable=true, display=1} )
    love.window.maximize()
    layout.W, layout.H = love.window.getMode()
    io.write("W,H=" .. layout.W .. " " .. layout.H .. "\n")

    -- adjust some windows accordingly
    layout.snapshotH = layout.H - layout.snapshotSize - snapshotMargin
    layout.HC = layout.H - 4 * intW - 3 * iconSize - layout.snapshotSize
    layout.WC = 1290 - 2 * intW
    viewh = layout.HC 		-- view height
    vieww = layout.W - 260	-- view width

    -- some initialization stuff
    generateUID = UIDiterator()

    -- launch further init procedure if possible or display setup window to require mandatory information. 
    if baseDirectory and baseDirectory ~= "" then
      init()
      initialized = true
    else
      dataWindow = setupWindow:new{ w=600, h=400, x=300,y=layout.H/2-100, init=false,layout=layout} 
      layout:addWindow( dataWindow , true, "dataWindow" )
      initialized = false
    end

    end

