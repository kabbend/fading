
local socket = require "socket"
 
-- the address and port of the server
local address, port = "localhost", 12345
local updaterate = 0.05 -- how long to wait, in seconds, before requesting an update
local currentImage = nil
local storedImage = nil
local mask = nil 
local mag = 0 -- a priori

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
  	--zx, zy = (W2 - w) / 2, (H2 - h) / 2
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
       		love.graphics.setStencilTest()
     	end

  end

  end

function love.update( dt )

  timer = timer + dt
  if (timer > updaterate) then

	timer = 0

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

	  elseif command == "HIDE" then
		currentImage = nil

	  elseif command == "DISP" then
		if storedImage then currentImage = storedImage end

	  elseif command == "CHXY" then
		local str = string.sub( data , 6)
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

	--until not data
	
  end

end

function love.keypressed( key )
 if key == "q" then love.event.quit() end
end

--
-- Main function
--
function love.load( args )

 timer = 0
 
 -- create socket and connect to the server
 udp = socket.udp()
 udp:settimeout(0)
 udp:setsockname("*", port)

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

