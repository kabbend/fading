local socket = require "socket"
 
-- the address and port of the server
local defaultAddress, port = "*", 12345
local updaterate = 0.05 	-- how long to wait, in seconds, before requesting an update

-- image information
local currentImage = nil	-- displayed image
local storedImage = nil		-- stored image (buffer before display)
local mask = nil		-- array of mask shapes, if any 
local mag = 0 			-- a priori
local W,H  			-- image dimensions, at scale 1

-- pawns
local pawns = {}

--[[ 
  Pawn object 
--]]
Pawn = {}
Pawn.__index = Pawn
function Pawn.new( id, filename, size, x, y , pj )

  local new = {}
  setmetatable(new,Pawn)

  -- get basic data
  new.id = id
  new.PJ = pj or false 
  new.x, new.y = x or 0, y or 0         -- relative to the map
  new.filename = imageFilename
  new.size = size                       -- size of the image in pixels, for map at scale 1

  -- set flags
  new.dead = false 			-- so far

  -- load pawn image
  local file = assert(io.open( filename , "rb" ))
  local image = file:read( "*a" )	
  file:close()
  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage
  new.im = lgn(lin(lfn(image, 'img', 'file')))
  assert(new.im, "sorry, could not load image at '" .. filename .. "'")

  -- compute scaling factor f, offsets (to center the image within the square)
  local w,h = new.im:getDimensions()
  local f1,f2 = size/w, size/h
  new.f = math.min(f1,f2)
  new.offsetx = (size - w * new.f ) / 2
  new.offsety = (size - h * new.f ) / 2

  return new
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


     	if mask and #mask > 0 then

       		love.graphics.setStencilTest("gequal", 2)
       		love.graphics.setColor(255,255,255)
       		love.graphics.draw( currentImage, zx, zy, 0, mag, mag )
	
		-- draw PNJ pawns 
		for i =1,#pawns do
		 local p = pawns[i]
		 if not p.PJ then 
                     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn is dead
                     local px,py = p.x * mag + zx , p.y * mag + zy
                     love.graphics.setColor(250,50,50)
                     love.graphics.rectangle( "fill", px-3, py-3, p.size * mag + 6, p.size * mag + 6)
                     if p.dead then love.graphics.setColor(50,50,50,200) else love.graphics.setColor(255,255,255) end
                     px = px + p.offsetx * mag
                     py = py + p.offsety * mag
                     love.graphics.draw( p.im , px, py, 0, p.f * mag , p.f * mag )
		 end
        	end

       		love.graphics.setStencilTest()

     	end

	-- draw PJ pawns (always on top)
	for i =1,#pawns do
		 local p = pawns[i]
		 if p.PJ then 
                     -- we do some checks before displaying the pawn: it might happen that the character corresponding to the pawn is dead
                     local px,py = p.x * mag + zx , p.y * mag + zy
                     love.graphics.setColor(50,50,250)
                     love.graphics.rectangle( "fill", px-3, py-3, p.size * mag + 6, p.size * mag + 6)
                     if p.dead then love.graphics.setColor(50,50,50,200) else love.graphics.setColor(255,255,255) end
                     px = px + p.offsetx * mag
                     py = py + p.offsety * mag
                     love.graphics.draw( p.im , px, py, 0, p.f * mag , p.f * mag )
		 end
        end

     end
 
  end

function love.update( dt )

  --timer = timer + dt
  --if (timer > updaterate) then

	--timer = 0

  	  local data, msg = udp:receive()
	  if data then 

	-- supported commands are:
	--
	-- OPEN filename	open a new filename from disk, store it but do not display it yet (waiting DISP command)
	--			remove current image from screen if any. Reset position, scaling (magnifier) factor and mask
	--			to default values (image is centered by default, factor is computed to be fullscreen, and no mask)
	--
	-- DISP			display last opened image, applying a stencil if needed. This command is used at the 
	--			end of the transmission, to indicate that the RECT and CIRC sequence is complete and the 
	--			full mask can now be displayed. Note that by default, an image is considered as having no
	--			mask at all (and thus is fully displayed), unless a sequence of RECT/CIRC has been sent
	--			between the last OPEN and the DISP command. These RECT/CIRC commands indicate that the
	--			image has stencils ( = unmask shapes ), thus a full (black) mask is displayed on top when
	--			using DISP. 
	--
	-- HIDE			hide current image (black screen), do not change stored one or current mask or scaling factor 
	--			if any
	--
	-- MAGN f 		set scaling (magnifier) factor (a decimal number)
	--
	-- CHXY x y 		change position to x , y (relative to image with scaling factor = 1)
	--
	-- RECT x y w h		set a new stencil (unmask) rectangle at corner x,y, and of dimensions w and h (relative to image
	--			with scaling factor = 1)
	--
	-- CIRC x y r 		set a new stencil (unmask) circle at position x,y, of radius r (a decimal number)
	--
	-- PAWN id x y s p filename
	--			create a new pawn with id, at position x,y (relative to the map at scale 1), of size s (in pixels 
	--			at scale 1), with boolean true/false p (if PJ or not), with image filename
	--
	-- KILL id		kill pawn with id given
	--
	-- MPAW id x y		move pawn id to new position x,y (relative to the map at scale 1)
	--
	
	  local command = string.sub( data, 1, 4)

	  if command == "OPEN" then

		local filename = string.sub( data , 6)
		local file = assert(io.open( filename , "rb" ))
		local image = file:read( "*a" )	
		file:close()

	    	local lfn = love.filesystem.newFileData
  	    	local lin = love.image.newImageData
  	    	local lgn = love.graphics.newImage

    	    	img = lgn(lin(lfn(image, 'img', 'file')))
		assert(img, "sorry, could not load image at '" .. filename .. "'")

		-- store new image
    	    	storedImage = img
  		W, H = storedImage:getDimensions()
  		xfactor = W2 / W
  		yfactor = H2 / H

		-- default position, centered
		X, Y = W / 2 , H / 2

		-- reset previous image
		currentImage = nil
		mag = 0
	    	mask = nil

	  elseif command == "PAWN" then
		local str = string.sub(data , 6)
		local _,_,id,x,y,size,pj,f = string.find( str, "(%a+) (%d+) (%d+) (%d+) (%d) (.*)" )
 		if pj == "1" then pj = true; else pj = false end
		table.insert( pawns, Pawn.new(id,f,size,x,y,pj) )
		
	  elseif command == "MPAW" then
		local str = string.sub(data , 6)
		local _,_,id,x,y = string.find( str, "(%a+) (%d+) (%d+)" )
		for i=1,#pawns do if pawns[i].id == id then pawns[i].x = x; pawns[i].y = y end end

	  elseif command == "KILL" then
		local str = string.sub(data , 6)
		local _,_,id = string.find( str, "(%a+)" )
		for i=1,#pawns do if pawns[i].id == id then pawns[i].dead = true end end

	  elseif command == "HIDE" then
		currentImage = nil

	  elseif command == "DISP" then
		if storedImage then currentImage = storedImage end

	  elseif command == "CHXY" then
		local str = string.sub(data , 6)
		local _,_,x,y = string.find( str, "(%d+) (%d+)" )
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

  --end

end

function love.keypressed( key )
 if key == "q" then love.event.quit() end
end

--
-- Main function
--
function love.load( args )

 --timer = 0

 local address = args[2] or defaultAddress
 
 -- create socket and connect to the server
 udp = socket.udp()
 udp:settimeout(0)
 udp:setsockname(address, port)

  -- GUI initializations
  -- we try to go to 2nd display
 love.window.setMode( 0, 0 , { x = 5, y = 5 , fullscreen=false, resizable=true, display=2} )

 -- check if we are on a 2nd display or not
 W2,H2,f = love.window.getMode()
 if f.display == 2 then
   -- OK, go fullscreen !
   love.window.setFullscreen( true )
   W2,H2 = love.window.getMode()
 end

end

