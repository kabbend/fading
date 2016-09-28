
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
                local _,_,shape,x,y,wm,hm = string.find( v , "(%a+) (%d+) (%d+) (%d+) (%d+)" )
                x = zx + x*mag
                y = zy + y*mag
                if shape == "RECT" then love.graphics.rectangle( "fill", x, y, wm*mag, hm*mag) end
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

	-- possible commands are
	-- OPEN filename
	-- DISP
	-- HIDE
	-- MAGN n.n
	-- CHXY x y 
	-- RECT x y w h
	
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
		currentImage = storedImage

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

