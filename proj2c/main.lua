local socket = require 'socket'
local parser = require 'parse'
local tween  = require 'tween'
local codepage = require 'codepage'

if love.system.getOS() == "Windows" then __WINDOWS__ = true end

-- the address and port of the server
defaultAddress, port, portbin 	= "localhost", 12345, 12346	-- default for primary server
connect = 		{ false, false }		-- connection status to primary and secondary server
serverOS = 		{ nil, nil }
tcp = 			{}
server			= 1				-- primary server by default
timer 			= 0
connectRetryTime 	= 5

-- image information
currentImage = nil	-- displayed image
storedImage = nil	-- stored image (buffer before display)
mask = nil		-- array of mask shapes, if any 
mag = 0 		-- a priori
W,H = 0,0 		-- image dimensions, at scale 1
X,Y = 0,0		-- current center position of the image

-- file loaded over the network
fullBinary 	= false
tempfile 	= nil

-- pawns
pawns 		= {}
maxLayer 	= 1		-- current layer value
pawnMovingTime	= 2		-- how many seconds to complete a movement on the map

-- mouse interaction
pawnMove 	= nil			-- information on the current pawn movement
arrowMode 	= false			-- are we currently drawing an arrow ?
arrowStartX, arrowStartY = nil, nil	-- starting point of the move (and the arrow)
arrowX, arrowY	= nil, nil		-- current end point

local oldiowrite = io.write
function io.write( data ) if debug then oldiowrite( data ) end end

function redressFilename( filename, server )
  if serverOS[server] == love.system.getOS() then return filename end -- nothing to redress
  local f = ""
  local i = 1
  repeat 
    local char = string.sub( filename , i , i )
    if char == antisep then f = f .. sep else f = f .. char end 
    i = i + 1
  until char == ""
  return f
end

--[[ 
  Pawn object 
--]]
Pawn = {}
function Pawn:new( server, id, filename, sizex, x, y , pj )

  local new = {}
  setmetatable(new,self)
  self.__index = self

  filename = redressFilename( baseDirectory .. sep .. filename, server )

  -- set basic data
  new.id = id
  new.PJ = pj or false 
  new.dead = false 					-- so far
  new.x = x or 0 					-- position of the upper left corner of the pawn, relative to the map
  new.y = y or 0         				-- position of the upper left corner of the pawn, relative to the map
  new.moveToX, new.moveToY = new.x, new.y		-- destination for a move
  new.timer = nil					-- tween timer to perform the move
  new.layer = maxLayer					-- determine if a pawn is drawn on top (or below) another one
  new.color = { 255, 255, 255 }				-- base color is white a priori
  if new.PJ then new.layer = new.layer + 10e6 end	-- PJ are always on top, so we increase their layer artificially !
  new.filename = filename
  -- load pawn image

  if __WINDOWS__ then filename = codepage.utf8tocp1252(filename) end

  local file = io.open( filename , "rb" )
  if not file then
	  io.write("cannot open file " .. filename .. "\n")
	  return nil
  end
  local image = file:read( "*a" )	
  file:close()
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  new.im = lgn(lin(lfn(image, 'img', 'file')))

  -- compute scaling factor f, offsets (to center the image within the square)
  local w,h = new.im:getDimensions()

  new.sizex = sizex                       -- width size of the image in pixels, for map at scale 1. The image is 
					 -- modified (with factor f) to fit the appropriate rectangular shape 

  new.sizey = new.sizex * (h/w)

  local f1,f2 = new.sizex/w, new.sizey/h
  new.f = math.min(f1,f2)
  new.offsetx = (new.sizex + 3*2 - w * new.f ) / 2
  new.offsety = (new.sizey + 3*2 - h * new.f ) / 2

  return new
  end

function Pawn:newBinary( id, sizex, x, y , pj , img )

  local new = {}
  setmetatable(new,self)
  self.__index = self

  -- set basic data
  new.id = id
  new.PJ = pj or false 
  new.dead = false 					-- so far
  new.x = x or 0 					-- position of the upper left corner of the pawn, relative to the map
  new.y = y or 0         				-- position of the upper left corner of the pawn, relative to the map
  new.moveToX, new.moveToY = new.x, new.y		-- destination for a move
  new.timer = nil					-- tween timer to perform the move
  new.layer = maxLayer					-- determine if a pawn is drawn on top (or below) another one
  new.color = { 255, 255, 255 }				-- base color is white a priori
  if new.PJ then new.layer = new.layer + 10e6 end	-- PJ are always on top, so we increase their layer artificially !
  new.filename = nil 
  new.im = img 
  -- compute scaling factor f, offsets (to center the image within the square)
  local w,h = new.im:getDimensions()
  new.sizex = sizex                       -- width size of the image in pixels, for map at scale 1. The image is 
					 -- modified (with factor f) to fit the appropriate rectangular shape 
  new.sizey = new.sizex * (h/w)
  local f1,f2 = new.sizex/w, new.sizey/h
  new.f = math.min(f1,f2)
  new.offsetx = (new.sizex + 3*2 - w * new.f ) / 2
  new.offsety = (new.sizey + 3*2 - h * new.f ) / 2
  return new
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

-- return a pawn if position x,y on the screen (typically, the mouse), is
-- inside any pawn of the map. If several pawns are superposed at this position,
-- take the one with highest layer value 
function isInsidePawn(x,y)
  local maxlayer , indexWithMaxLayer = 0 , 0
  local zx,zy = -( X * mag - W2 / 2), -( Y * mag - H2 / 2)
  for i=1,#pawns do
                local lx,ly = pawns[i].x, pawns[i].y -- position x,y relative to the map, at scale 1
                local tx,ty = zx + lx * mag, zy + ly * mag -- position tx,ty relative to the screen
                local sizex = pawns[i].sizex * mag -- size relative to the screen
                local sizey = pawns[i].sizey * mag -- size relative to the screen
                if x >= tx and x <= tx + sizex and y >= ty and y <= ty + sizey and pawns[i].layer > maxlayer then  
			maxlayer = pawns[i].layer
			indexWithMaxLayer = i
		end
  end
  if indexWithMaxLayer == 0 then return nil else return pawns[ indexWithMaxLayer ] end 
end

function love.mousepressed (x,y)
	
	local p = isInsidePawn(x,y)

        if p and p.PJ and not p.dead then

                  -- clicking on an (alive PJ) pawn will start an arrow that will represent
                  -- * either an attack, if the arrow ends on another pawn
                  -- * or a move, if the arrow ends somewhere else on the map
                  pawnMove = p
                  arrowMode = true
                  arrowStartX, arrowStartY = x, y
	end
end

function love.mousereleased (x,y)
        -- we were moving a pawn. we stop now
        if pawnMove then

                arrowMode = false

                local target = isInsidePawn(x,y)
                if target and target ~= pawnMove then

                        -- we have a target
                        tcp[server]:send( "TARG " .. pawnMove.id .. " " ..  target.id .. "\n") 

                else

                        -- it was just a move, change the pawn position
                        -- we consider that the mouse position is at the center of the new image
			local zx,zy = -( X * mag - W2 / 2), -( Y * mag - H2 / 2)
                        pawnMove.moveToX, pawnMove.moveToY = (x - zx) / mag - pawnMove.sizex / 2 , (y - zy) / mag - pawnMove.sizey / 2

			-- the last pawn to move is always on top, except if it is a PNJ
			maxLayer = maxLayer + 1
			pawnMove.layer = maxLayer
			if pawnMove.PJ then pawnMove.layer = pawnMove.layer + 10e6 end
			table.sort( pawns , function (a,b) return a.layer < b.layer end )

                        -- we must stay within the limits of the map    
                        if pawnMove.moveToX < 0 then pawnMove.moveToX = 0 end
                        if pawnMove.moveToY < 0 then pawnMove.moveToY = 0 end
                        if pawnMove.moveToX + pawnMove.sizex + 6 > W then pawnMove.moveToX = math.floor(W - pawnMove.sizex - 6) end
                        if pawnMove.moveToY + pawnMove.sizey + 6 > H then pawnMove.moveToY = math.floor(H - pawnMove.sizey - 6) end

			pawnMove.timer = tween.new( pawnMovingTime, pawnMove, { y = pawnMove.moveToY, x = pawnMove.moveToX } )

                        tcp[server]:send("MPAW " .. pawnMove.id .. " " ..  math.floor(pawnMove.moveToX) .. " " .. math.floor(pawnMove.moveToY) .. "\n")

                end
                pawnMove = nil;
        end
end

function myStencilFunction() 
        love.graphics.rectangle("fill",zx,zy,w,h)
        for k,v in pairs(mask) do
                local _,_,shape = string.find( v , "(%a+)" )
                if shape == "RECT" then
                        local _,_,_,x,y,wm,hm = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+) (%d+)" )
                        x = zx + x*mag
                        y = zy + y*mag
                        love.graphics.rectangle( "fill", x, y, wm*mag, hm*mag)
                elseif shape == "CIRC" then
                        local _,_,_,x,y,r = string.find( v , "(%a+) (%-?%d+) (%-?%d+) (%d+%.?%d+)" )
                        x = zx + x*mag
                        y = zy + y*mag
                        love.graphics.circle( "fill", x, y, r*mag )
                end
        end
        end

function love.draw()

  if currentImage then 

	love.graphics.setColor(255,255,255)

	-- if mag is not set, means fullscreen
	if mag == 0 then
  		mag = math.min( xfactor, yfactor )
  		if mag > 2 then mag = 2 end
	end

	-- apply mag factor to the image size
  	w , h = W * mag, H  * mag

	-- center the image 
	zx,zy = -( X * mag - W2 / 2), -( Y * mag - H2 / 2)

	if mask and #mask > 0 then

       		love.graphics.setColor(0,0,0)
       		love.graphics.stencil( myStencilFunction, "increment" )
       		love.graphics.setStencilTest("equal", 1)

     	else

       		love.graphics.setColor(255,255,255)

     	end

  	love.graphics.draw( currentImage , zx , zy , 0 , mag, mag )

	-- draw PNJ pawns, the lowest layer value first

     	if mask and #mask > 0 then

       		love.graphics.setStencilTest("gequal", 2)
       		love.graphics.setColor(255,255,255)
       		love.graphics.draw( currentImage, zx, zy, 0, mag, mag )

		for i =1,#pawns do
		 local p = pawns[i]
		 if not p.PJ then 
                     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn is dead
                     local px,py = p.x * mag + zx , p.y * mag + zy
                     love.graphics.setColor(250,50,50)
                     love.graphics.rectangle( "fill", px, py, (p.sizex + 6 ) * mag ,(p.sizey + 6) * mag )
                     if p.dead then 
			love.graphics.setColor(50,50,50,200) 
		     else 
			love.graphics.setColor(unpack(p.color)) 
		     end
                     px = px + p.offsetx * mag
                     py = py + p.offsety * mag
                     love.graphics.draw( p.im , px, py, 0, p.f * mag , p.f * mag )
		     p.color = { 255, 255, 255 } -- restore base color
		 end
        	end

       		love.graphics.setStencilTest()

     	end

	-- draw PJ pawns (always visible, even if there is a mask)
	for i =1,#pawns do
		 local p = pawns[i]
		 if p.PJ then 
                     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn is dead
                     local px,py = p.x * mag + zx , p.y * mag + zy
                     love.graphics.setColor(50,50,250)
                     love.graphics.rectangle( "fill", px, py, (p.sizex + 6) * mag, (p.sizey + 6) * mag)
                     if p.dead then 
			love.graphics.setColor(50,50,50,200) 
		     else 
			love.graphics.setColor(unpack(p.color)) 
		     end
                     px = px + p.offsetx * mag
                     py = py + p.offsety * mag
                     love.graphics.draw( p.im , px, py, 0, p.f * mag , p.f * mag )
		     p.color = { 255, 255, 255 } -- restore base color
		 end
        end

  	if arrowMode then
      		-- draw arrow and arrow head
      		love.graphics.setColor(250,0,0)
      		love.graphics.line( arrowStartX, arrowStartY, arrowX, arrowY )
      		local x3, y3, x4, y4 = computeTriangle( arrowStartX, arrowStartY, arrowX, arrowY)
      		if x3 then
        		love.graphics.polygon( "fill", arrowX, arrowY, x3, y3, x4, y4 )
      		end
  	end

     end
 
  end

function love.update( dt )

 	if secondary then
		-- alternate server if applicable
		if server == 1 then server = 2 else server = 1 end
	else
		server = 1 -- only primary
	end

	-- store current mouse position in arrow mode
        if arrowMode then
                arrowX, arrowY = love.mouse.getPosition()
        end

	-- change color to red when pawn is target of an arrow
        if pawnMove then
                local target = isInsidePawn(arrowX,arrowY)
                if target and target ~= pawnMove then
			target.color = { 255 , 0 , 0 }
		end
	end

	-- move pawns if needed
	for k,v in ipairs(pawns) do
		if v.timer then v.timer:update(dt) end
	end

	-- socket communication
	timer = timer + dt

	if (not connect[1]) and timer > connectRetryTime then
		-- nobody was listening, probably. we retry
		io.write("calling primary server...\n")
		if fullBinary then tcp[1]:send("CONNECTB\n") else tcp[1]:send("CONNECT\n") end
		timer = 0
	end

	if secondary and (not connect[2]) and timer > connectRetryTime then
		-- nobody was listening, probably. we retry
		io.write("calling secondary server...\n")
		if fullBinary then tcp[2]:send("CONNECTB\n") else tcp[2]:send("CONNECT\n") end
		timer = 0
	end

  	local data, msg = tcp[server]:receive()

	if data then 

	  io.write("receiving data from server " .. server .. " : " .. data .. "\n")

	-- supported commands are:
	--
	-- working with server:
	--
	--   CONN MAC|WIN		Connected. Answer from server. Gives indication on incoming paths format (esp. separator)
	--				depending on windows or Mac
	--
	-- working with images and maps:
	--
	--   OPEN filename		open a new filename from disk, store it but do not display it yet (waiting DISP command)
	--				remove current image from screen if any. Reset position, scaling (magnifier) factor and mask
	--				to default values (image is centered by default, factor is computed to be fullscreen, and no mask).
	--   DISP			Display last opened image, applying a stencil if needed. This command is used at the 
	--				end of the transmission, to indicate that the RECT and CIRC sequence is complete and the 
	--				full mask can now be displayed. Note that by default, an image is considered as having no
	--				mask at all (and thus is fully displayed), unless a sequence of RECT/CIRC has been sent
	--				between the last OPEN and the DISP command. These RECT/CIRC commands indicate that the
	--				image has stencils ( = unmask shapes ), thus a full (black) mask is displayed on top when using DISP. 
	--   HIDE			Hide current image (black screen), do not change stored one or current mask or scaling factor if any
	--   MAGN f 			Set scaling (magnifier) factor (a decimal number)
	--   CHXY x y 			Change position to x , y (relative to image with scaling factor = 1)
	--   RECT x y w h		Set a new stencil (unmask) rectangle at corner x,y, and of dimensions w and h (relative to imag	with scaling factor = 1)
	--   CIRC x y r			Set a new stencil (unmask) circle at position x,y, of radius r (a decimal number)
	--
	-- working with pawns:
	--
	--   PAWN id x y s p filename	Create a new pawn with id, at position x,y (relative to the map at scale 1), of size s (width in pixels 
	--				at scale 1), with boolean true/false p (if PJ or not), with image filename
	--   KILL id			Kill pawn with id given
	--   ERAS 			Remove all pawns from the map
	--   ERAP id			Remove one pawn from the map
	--   MPAW id x y		Move pawn id to new position x,y (relative to the map at scale 1)
	--
	-- working with binary files:
	--
	--   BNRY 			Binary file is about to be sent. Will be done when BEOF or PEOF is received
	--   BEOF			End of binary file. Store the received data as an image or a map
	--   PEOF id x y s p		End of binary file. Store the received data as a pawn image. The pawn is created at the same time
	--
	
	  local command = string.sub( data, 1, 4)

	  if command == "BNRY" then

		io.write("receiving BNRY\n") 
		tempfile = io.open("image.tmp",'wb')

		-- open a new connection to server, dedicated to binary transfer
 		local readbin = socket.tcp()
 		readbin:settimeout(0)
 		readbin:connect(address, portbin) 
 		if readbin then
  			io.write("connected for binary transfer\n")
 		end
		local data, msg
  		repeat
		  data, msg, partial = readbin:receive("*a")
		  data = data or partial
		  if data then 
			tempfile:write(data); 
			io.write("receiving " .. string.len(data) .. " bytes\n") 
		  end
		 socket.sleep(0.05)
		 until msg =="closed" 

		readbin:close() -- closing the binary socket

	   elseif command == "BEOF" then

		io.write("receiving BEOF\n") 

		tempfile:close()

		tempfile = io.open("image.tmp", 'rb')
            	local image = tempfile:read("*a")
            	tempfile:close()

            	local lfn = love.filesystem.newFileData
            	local lin = love.image.newImageData
            	local lgn = love.graphics.newImage
            	local success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)

		-- store new image
    	    	storedImage = img
  		success, W, H = pcall( function() return storedImage:getDimensions() end )
		if not success then 
			io.write("sorry, something bad happened in getDimensions() ... \n")
			storedImage = nil
		else
  			xfactor = W2 / W
  			yfactor = H2 / H

			-- default values
			X, Y = W / 2 , H / 2
			mag = 0
		end
		
		-- reset previous image
		currentImage = nil
	    	mask = nil

	  --end

	  elseif command == "PEOF" then

		io.write("receiving PEOF\n") 

		tempfile:close()

		tempfile = io.open("image.tmp", 'rb')
            	local image = tempfile:read("*a")
            	tempfile:close()

            	local lfn = love.filesystem.newFileData
            	local lin = love.image.newImageData
            	local lgn = love.graphics.newImage
            	local success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)
  		local success, w, h = pcall( function() return storedImage:getDimensions() end )
		if not success then 
			io.write("sorry, something bad happened in getDimensions() ... \n")
		end
		
		local str = string.sub(data , 6)
		local _,_,id,x,y,size,pj = string.find( str, "(%a+) (%d+) (%d+) (%d+) (%d)" )
		-- The two innocent lines below are important: x and y are parsed as strings, not numbers, 
		-- which cause issue later with tween function expecting type(number)... we force them to be numbers here...
		x = x + 0
		y = y + 0 
 		if pj == "1" then pj = true; else pj = false end
		local p = Pawn:newBinary(id,size,x,y,pj,img) 
		if p then 
			table.insert( pawns, p ) 
			table.sort( pawns , function (a,b) return a.layer < b.layer end )
		end

	  end
	
	  if command == "CONN MAC" then
 	  	io.write("Connected to " .. address .. " " .. port .. ", Mac server\n")
		serverOS[server] = "OS X"
		connect[server] = true
	  elseif command == "CONN WIN" or command == "CONN" then
 	  	io.write("Connected to " .. address .. " " .. port .. ", Windows server\n")
		serverOS[server] = "Windows"
		connect[server] = true
	  end

	  if command == "OPEN" then

		local rawfilename = string.sub( data , 6)

		local filename = redressFilename ( rawfilename, server )

		io.write("redressing filename, from " .. rawfilename .. " to " .. filename .. "\n")

		filename = baseDirectory .. sep .. filename 

  		if __WINDOWS__ then filename = codepage.utf8tocp1252(filename) end

		local file = io.open( filename , "rb" )
		if not file then
			io.write("sorry, cannot open file at " .. filename .. "\n")
			return
		end
		local image = file:read( "*a" )	
		file:close()

	    	local lfn = love.filesystem.newFileData
  	    	local lin = love.image.newImageData
  	    	local lgn = love.graphics.newImage

    	    	img = lgn(lin(lfn(image, 'img', 'file')))

		-- store new image
    	    	storedImage = img
  		success, W, H = pcall( function() return storedImage:getDimensions() end )
		if not success then 
			io.write("sorry, something bad happened in getDimensions() ... \n")
			storedImage = nil
		else
  			xfactor = W2 / W
  			yfactor = H2 / H

			-- default values
			X, Y = W / 2 , H / 2
			mag = 0
		end

		-- reset previous image
		currentImage = nil
	    	mask = nil

	  elseif command == "PAWN" then
		local str = string.sub(data , 6)
		local _,_,id,x,y,size,pj,f = string.find( str, "(%a+) (%d+) (%d+) (%d+) (%d) (.*)" )
		-- The two innocent lines below are important: x and y are parsed as strings, not numbers, 
		-- which cause issue later with tween function expecting type(number)... we force them to be numbers here...
		x = x + 0
		y = y + 0 
 		if pj == "1" then pj = true; else pj = false end
		local p = Pawn:new(id,f,size,x,y,pj) 
		if p then 
			table.insert( pawns, p ) 
			table.sort( pawns , function (a,b) return a.layer < b.layer end )
		end
	
	  elseif command == "MPAW" then
		local str = string.sub(data , 6)
		local _,_,id,x,y = string.find( str, "(%a+) (%d+) (%d+)" )
		-- The two innocent lines below are important: x and y are parsed as strings, not numbers, 
		-- which cause issue later with tween function expecting type(number)... we force them to be numbers here...
		x = x + 0
		y = y + 0 
		for i=1,#pawns do 
			if pawns[i].id == id then 
				pawns[i].moveToX = x; pawns[i].moveToY = y 
				maxLayer = maxLayer + 1
				pawns[i].layer = maxLayer
				if pawns[i].PJ then pawns[i].layer = pawns[i].layer + 10e6 end
				pawns[i].timer = tween.new( pawnMovingTime, pawns[i], { x = pawns[i].moveToX, y = pawns[i].moveToY } )
			end 
		end
		table.sort( pawns , function (a,b) return a.layer < b.layer end )

	  elseif command == "KILL" then
		local str = string.sub(data , 6)
		local _,_,id = string.find( str, "(%a+)" )
		for i=1,#pawns do if pawns[i].id == id then pawns[i].dead = true end end

	  elseif command == "ERAP" then
		local str = string.sub(data , 6)
		local _,_,id = string.find( str, "(%a+)" )
		for i=1,#pawns do if pawns[i].id == id then 
			table.remove( pawns, i ) 
			break 
		end end

	  elseif command == "ERAS" then
		pawns = {}

	  elseif command == "HIDE" then
		currentImage = nil

	  elseif command == "DISP" then
		if storedImage then currentImage = storedImage end

	  elseif command == "CHXY" then
		local str = string.sub(data , 6)
		local _,_,x,y = string.find( str, "(%-?%d+) (%-?%d+)" )
		X, Y = x , y 

	  elseif command == "MAGN" then
		local magstr = string.sub( data , 6)
		local _,_,m = string.find( magstr, "(%d*%.?%d+)" )
		mag = tonumber( m )

	  elseif command == "RECT" then
		if not mask then mask = {} end
		table.insert( mask , data )

	  elseif command == "CIRC" then
		if not mask then mask = {} end
		table.insert( mask , data )

	  end

	  end

          socket.sleep(0.01)

end

function love.keypressed( key )
 if key == "q" then love.event.quit() end
end

--
-- Main function
--
function love.load( args )

 dofile("pconf.lua")

 -- PRIMARY SERVER
 address = serverip 
 port = serverport 
 portbin = serverport + 1

 -- (OPTIONAL) SECONDARY SERVER
 if secondaryserverip and secondaryserverip ~= "" then
   addressSec = secondaryserverip 
   portSec = secondaryserverport 
   portbinSec = secondaryserverport + 1
   secondary = true
 end

 debug = true

 -- no directory provided, we will request full binary mode to the server
 if baseDirectory == "" then fullBinary = true end

 io.write("IP address = " .. address .. "\n")
 if secondary then io.write("secondary IP address = " .. addressSec .. "\n") end
 io.write("base directory = " .. baseDirectory .. "\n")
 
 if love.system.getOS() == "OS X" then sep = "/"; antisep = "\\";  else sep = "\\" ; antisep = "/" end

 -- create socket and connect to the server
 tcp[1] = socket.tcp()
 tcp[1]:settimeout(0)
 -- trying to reach server
 tcp[1]:connect(address, port) 
 if fullBinary then tcp[1]:send("CONNECTB\n") else tcp[1]:send("CONNECT\n") end

 if secondary then
   tcp[2] = socket.tcp()
   tcp[2]:settimeout(0)
   -- trying to reach server
   tcp[2]:connect(addressSec, portSec) 
   if fullBinary then tcp[2]:send("CONNECTB\n") else tcp[2]:send("CONNECT\n") end
 end

 
 -- GUI initializations
 -- in remote: we go to 1st display fullscreen
 -- in local: we try to go to 2nd display fullscreen, otherwise go to 1st display standard 
 local disp = 1
 local full = true
 if address == "localhost" then disp = 2; full = false end

 love.window.setMode( 0, 0 , { x = 0, y = 0 , fullscreen=full, resizable=true, display=disp} )

 -- check if we are on a 2nd display or not
 W2,H2,f = love.window.getMode()
 if f.display == 2 then
   -- OK, go fullscreen !
   love.window.setFullscreen( true )
   W2,H2 = love.window.getMode()
 end

end

