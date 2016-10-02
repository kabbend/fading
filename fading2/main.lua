
-- interface import
local yui 	= require 'yui.yaoui' 	-- Graphical library on top of Love2D
local socket 	= require 'socket'
local utf8 	= require 'utf8'

--
-- GLOBAL VARIABLES
--
-- the address and port of the projector client
address, port = "localhost", 12345

-- main screen size
W, H = 1420, 730 	-- main window size default values (may be changed dynamically on some systems)
viewh = H - 170 	-- view height
size = 19 		-- base font size
margin = 20		-- screen margin in map mode

-- snapshots
snapshots = {}
snapshotIndex = 1	-- which image is first
snapshotSize = 70 	-- w and h of each snapshot
snapshotMargin = 7 	-- space between images and screen border
snapshotOffset = 0	-- current offset to display

-- PJ snapshots
displayPJSnapshots = true

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
Mode 			= "combat"		-- mode can be 'combat' (default) or 'map'
textBase		= "Search : "
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
drawDicesTimer      = 0
drawDices           = false	-- flag to draw dices
drawDicesResult     = false	-- flag to draw dices result (in a 2nd step)	
Dices 		    = {}	-- values of the dices
diceKind 	    = ""	-- kind of dice (black for 'attack', white for 'armor')

-- information to draw the arrow in combat mode
arrowMode 		 = false	-- draw an arrow with mouse, yes or no
arrowStartX, arrowStartY = 0,0		-- starting point of the arrow	
arrowX, arrowY 		 = 0,0		-- current end point of the arrow
arrowStartIndex 	 = nil		-- index of the PNJ at the starting point
arrowStopIndex 		 = nil		-- index of the PNJ at the ending point
arrowModeMap		 = "RECT"	-- shape used to draw map mask, rectangles by default

-- capture text input (for text search)
function love.textinput(t)
	if not searchActive then return end
	if ignoreLastChar then ignoreLastChar = false; return end
	text = text .. t
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

-- send an image (already stored in memory) to the projector
function sendOver( map )

  udp:send("OPEN " .. map.filename )

  -- send mask if applicable
  if map.mask then
	for k,v in pairs( map.mask ) do
		udp:send( v )
	end
  end

  udp:send("MAGN " .. 1/map.mag)
  udp:send("CHXY " .. map.x .. " " .. map.y )
  udp:send("DISP")

  end

-- dropping a file over the main window will: 
-- * create a snapshot at bottom right of the screen,
-- * send this same image over the socket to the projector client
-- * if a map was visible, it is now hidden
function love.filedropped(file)

  	if file:open('r') then

   		-- create a snapshot
        	local image = file:read()
        	file:close()

        	local lfn = love.filesystem.newFileData
        	local lin = love.image.newImageData
        	local lgn = love.graphics.newImage
        	success, img = pcall(function() return lgn(lin(lfn(image, 'img', 'file'))) end)
        	if success then 

	  	-- set the local image
	  	currentImage = img 

		-- remove the 'visible' flag from maps (eventually)
		atlas:removeVisible()
	
    	  	-- send the filename over the socket
		local filename = file:getFilename()
		udp:send("OPEN " .. filename)
		udp:send("DISP") 	-- display immediately
		
		end

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

	-- roll them all and store result
  	Dices = {}
  	for i=1,num do Dices[i] = math.random(1,6) end

	-- give go to draw them
  	drawDicesTimer = 0
  	drawDices = true
  	drawDicesResult = false

	end



-- GUI basic functions
function love.update(dt)

	if displayPJSnapshots then

	  -- if focus changed, send a new PJ snapshot to the projector, or a HIDe command, eventually
	  if focus and lastFocus ~= focus then
		if PNJTable[focus].PJ and PNJTable[focus].snapshot then
			udp:send("SNAP " .. PNJTable[focus].snapshot.filename ) 
		elseif not PNJTable[focus].PJ then
    			local index = findPNJ(PNJTable[focus].target)
			if index and PNJTable[index].PJ and PNJTable[index].snapshot then
				udp:send("SNAP " .. PNJTable[index].snapshot.filename ) 
			else 
				udp:send("HIDS") 

			end
		end
		lastFocus = focus -- avoid to do this next time...
	  end
	  if not focus and lastFocus ~= focus then
		udp:send("HIDS") 
		lastFocus = nil -- avoid to do this next time...
	  end

	end

	-- change snapshot offset if mouse  at bottom right or left
	local snapMax = #snapshots * (snapshotSize + snapshotMargin) - W
	if snapMax < 0 then snapMax = 0 end
	local x,y = love.mouse.getPosition()
	if (x < snapshotMargin * 4 ) and (y > H - snapshotMargin - snapshotSize ) then
	  snapshotOffset = snapshotOffset + snapshotMargin * 2
	  if snapshotOffset > 0 then snapshotOffset = 0  end
	end
	if (x > W - snapshotMargin * 4 ) and (y > H - snapshotMargin - snapshotSize ) then
	  snapshotOffset = snapshotOffset - snapshotMargin * 2
	  if snapshotOffset < -snapMax then snapshotOffset = -snapMax end
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
    		drawDicesTimer = drawDicesTimer + dt
    		if (drawDicesTimer >= 1) then
      			if not drawDicesResult then drawDicesTimer = 0; drawDices = true; drawDicesResult = true;
      			else drawDicesTimer = 0; drawDices = false; drawDicesResult = false;
      			end
    		end
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
	local map = atlas:getMap()
	if not map then return end
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
  for i=snapshotIndex, #snapshots do
	local x = snapshotOffset + (snapshotSize + snapshotMargin) * (i-1) - (snapshots[i].w * snapshots[i].mag - snapshotSize) / 2
	if x > W then break end
	if x >= -snapshotSize then 
		if snapshots[i].selected then
  			love.graphics.setColor(unpack(color.red))
			love.graphics.rectangle("line", 
				snapshotOffset + (snapshotSize + snapshotMargin) * (i-1),
				H - snapshotSize - snapshotMargin, 
				snapshotSize, 
				snapshotSize)
  			love.graphics.setColor(255,255,255)
		end
		love.graphics.draw( 	snapshots[i].im , 
				x,
				H - snapshotSize - snapshotMargin - ( snapshots[i].h * snapshots[i].mag - snapshotSize ) / 2, 
			    	0 , snapshots[i].mag, snapshots[i].mag )
	end
  end

  -- small snapshot
  love.graphics.setColor(255,255,255)
  love.graphics.rectangle("line", W - W1 - 10, H - H1 - snapshotSize - snapshotMargin * 2 - 10 , W1 , H1 )
  if currentImage then 
    local w, h = currentImage:getDimensions()
    -- compute magnifying factor f to fit to screen, with max = 2
    local xfactor = W1 / w
    local yfactor = H1 / h
    local f = math.min( xfactor, yfactor )
    if f > 2 then f = 2 end
    w , h = f * w , f * h
    love.graphics.draw( currentImage , W - W1 - 10 +  (W1 - w) / 2, H - H1 - snapshotSize - snapshotMargin * 2 - 10 + ( H1 - h ) / 2, 0 , f, f )
  end

  --if not nextFlash then     -- no focus drawing if Next round zone is blinking

    love.graphics.setLineWidth(3)

    -- draw FOCUS if applicable
    love.graphics.setColor(0,102,0,alpha)
    if focus then love.graphics.rectangle("fill",PNJtext[focus].x+2,PNJtext[focus].y-5,W-12,42) end

    -- draw ATTACKERS if applicable
    love.graphics.setColor(204,102,0,alpha)
    if focusAttackers then
      for i,v in pairs(focusAttackers) do
        if v then
          local index = findPNJ(i)
          if index then love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,W-12,42) end
        end
      end
    end 

    -- draw TARGET if applicable
    love.graphics.setColor(250,80,80,alpha*1.5)
    local index = findPNJ(focusTarget)
    if index then love.graphics.rectangle("fill",PNJtext[index].x+2,PNJtext[index].y-5,W-12,42) end
  --else

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

  -- draw dices if needed
  if drawDices then

    total = 0

    local dices = {}
    if diceKind == "attack" then dices = diceB; else dices = diceW; end

    love.graphics.setColor(255,255,255)

    local x, y  = 0 , viewh / 2

    for i,v in ipairs(Dices) do
      if i == 11 or i == 21 or i == 31 or i == 41 or i == 51 then x = 80; y = y + 80;
      else x = x + 80; end
      if not drawDicesResult then 
        love.graphics.draw( dices[v] , x , y ) -- draw all dices first
      else
        if v < 5 then love.graphics.draw( dices[v] , x , y ) ; total = total + 1 ; end -- draw only 1-4 dices then
      end
    end

    -- draw number if needed
    if drawDicesResult then
      love.graphics.setColor(unpack(color.red))
      love.graphics.setFont(fontDice)
      love.graphics.print(tostring(total),650,4*viewh/5)
    end

  end 

  if arrowMode then

      -- draw arrow and arrow head
      love.graphics.setColor(unpack(color.red))
      love.graphics.line( arrowStartX, arrowStartY, arrowX, arrowY )
      local x3, y3, x4, y4 = computeTriangle( arrowStartX, arrowStartY, arrowX, arrowY)
      if x3 then
        love.graphics.polygon( "fill", arrowX, arrowY, x3, y3, x4, y4 )
      end
     
      -- draw rectangle or circle in map mode
      if Mode =="map" then
	-- draw circle or rectangle itself
	if arrowModeMap == "RECT" then 
		love.graphics.rectangle("line",arrowStartX, arrowStartY,(arrowX - arrowStartX),(arrowY - arrowStartY)) 
	elseif arrowModeMap == "CIRC" then 
		love.graphics.circle("line",(arrowStartX+arrowX)/2, (arrowStartY+arrowY)/2, distanceFrom(arrowX,arrowY,arrowStartX,arrowStartY) / 2) 
	end
      end 
 
    end
   
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
        offset = offset + 30
    end
    
    -- display ATTACKERS (in a colored circle) when applicable
    if PNJTable[i].attackers then
      local sorted = {}
      for id, v in pairs(PNJTable[i].attackers) do if v then table.insert(sorted,id) end end
      table.sort(sorted)
      for k,id in pairs(sorted) do
          local index = findPNJ(id)
          if index then drawRound( PNJtext[i].x + offset, PNJtext[i].y + 15, "attacker", id ) ; offset = offset + 30; end
      end
    end
    
    -- display dangerosity per PNJ
    if PNJTable[i].PJ then
      local danger = computeDangerosity( i )
      if danger ~= -1 then drawRound( PNJtext[i].x + offset, PNJtext[i].y + 15, "danger", tostring(danger) ) end
    end
    
  end
  
 if Mode == "map" then

   local map = atlas:getMap()

   if map then

     -- print image
     love.graphics.setScissor( margin , margin , W - margin * 2, H - margin * 2 )
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

     love.graphics.setScissor()

     -- draw small circle or rectangle in upper corner, to show which mode we are in
     if map.kind == "map" then
       love.graphics.setColor(200,0,0,180)
       if arrowModeMap == "RECT" then love.graphics.rectangle("line",margin + 5, margin + 5,20,20) end
       if arrowModeMap == "CIRC" then love.graphics.circle("line",margin + 15, margin + 15,10) end
     end

     -- print visible 
     if atlas:isVisible( map ) then
        love.graphics.setColor(200,0,0,180)
        love.graphics.setFont(fontDice)
	love.graphics.printf("VISIBLE",margin , margin ,500)
     end

     -- print search zone for a scenario
     if map.kind == "scenario" then

      love.graphics.setColor(0,0,0)
      love.graphics.setFont(fontSearch)
      love.graphics.printf(text, 800, H - 60, 400)

      -- activate search input zone if needed
      if not searchActive then searchActive = true end

      -- print number of the search result is needed
      if searchIterator then love.graphics.printf( "( " .. searchIndex .. " [" .. string.format("%.2f", searchPertinence) .. "] out of " .. searchSize .. " )", 800, H - 40, 400) end

     end

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

  	if not arrowMode then return end
 
 	if Mode == "combat" then
 
  	  -- check which PNJ was selected, depending on position on y-axis
  	  for i=1,PNJnum-1 do
    		if (y >= PNJtext[i].y-5 and y < PNJtext[i].y + 42) then
      			-- this stops the arrow mode
      			arrowMode = false
      			arrowStopIndex = i
      			-- set new target
      			if arrowStartIndex ~= arrowStopIndex then 
        			updateTargetByArrow(arrowStartIndex, arrowStopIndex) 
      			end
      			return
    		end
  	  end

	elseif Mode == "map" then

  	  arrowMode = false

  	  local map = atlas:getMap()
	  local command = nil

	  if arrowX < margin or arrowX > W or arrowY < margin or arrowY > H then return end

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
	  	sx = math.floor( sx + ( map.x / map.mag  - W / 2)) *map.mag 
	  	sy = math.floor( sy + ( map.y / map.mag  - H / 2)) *map.mag 
		local r = distanceFrom( arrowX, arrowY, arrowStartX, arrowStartY) * map.mag / 2
	  	if r ~= 0 then command = "CIRC " .. sx .. " " .. sy .. " " .. r end

	  end

	  if command then 
		table.insert( map.mask , command ) 
	  	-- send over if requested
	  	if atlas:isVisible( map ) then udp:send( command ) end
	  end
 
	end	

  
	end

	
-- put FOCUS on a PNJ line when mouse is pressed (or remove FOCUS if outside PNJ list)
function love.mousepressed( x, y )   

  if Mode == "map" then
	local map = atlas:getMap()
	if not map or map.kind == "scenario" then return end
	arrowMode = true
	arrowStartX, arrowStartY = x, y
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
    local index = math.floor((x - snapshotOffset) / ( snapshotSize + snapshotMargin)) + 1
    -- 2 possibilities: if this image is already selected, then display it
    -- otherwise, just select it (and deselect any other eventually)
    if index >= 1 and index <= #snapshots then
      if snapshots[index].selected then
	      -- already selected
	      snapshots[index].selected = false 
	      currentImage = snapshots[index].im
	      -- remove the 'visible' flag from maps (eventually)
	      atlas:removeVisible()
    	      -- send the filename over the socket
	      udp:send("OPEN " .. snapshots[index].filename)
	      udp:send("DISP") 	-- display immediately
      else
	      -- not selected, select it now
	    for i,v in ipairs(snapshots) do
	      if i == index then snapshots[i].selected = true
	      else snapshots[i].selected = false end
	    end
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
      if not PNJTable[i].PJ then
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

--[[ 
  Map object 
--]]
Map = {}
Map.__index = Map
function Map.new( kind, imageFilename ) 
  local new = {}
  setmetatable(new,Map)
  assert( kind == "map" or kind == "scenario" , "sorry, cannot create a map of such kind" )
  assert( imageFilename , "please provide a filename" )
  new.kind = kind
  local file = assert(io.open( imageFilename , "rb" ))
  local image = file:read( "*a" )
  file:close()

  local lfn = love.filesystem.newFileData
  local lin = love.image.newImageData
  local lgn = love.graphics.newImage

  local img = lgn(lin(lfn(image, 'img', 'file')))
  assert(img, "sorry, could not load image at '" .. imageFilename .. "'")  
  
  new.filename = imageFilename
  new.im = img 
  new.w, new.h = new.im:getDimensions() 
  new.x = new.w / 2
  new.y = new.h / 2
  new.mag = 1.0
  new.step = 50
  if kind == "map" then new.mask = {} else new.mask = nil end
  return new
  end

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
  new.im = img 
  new.w, new.h = new.im:getDimensions() 
  local f1, f2 = snapshotSize / new.w , snapshotSize / new.h
  new.mag = math.min(f1,f2)
  new.selected = false
  return new
  end

Atlas = {}
Atlas.__index = Atlas
function Atlas:addMap(m) 
	if m.kind == "scenario" then 
		for k,v in pairs(self.maps) do if v.kind == "scenario" then error("only 1 scenario allowed") end end
		table.insert(self.maps, 1,  m ) -- scenario always first 
	else
		table.insert(self.maps, m);  
	end
	if self.index == 0 then self.index = 1 end 
	end 

function Atlas:nextMap() 
	if #self.maps == 0 then return nil end 
	self.index = self.index + 1 
	if self.index > #self.maps then 
		self.index = 1
		return nil 
	else
		return self.maps[self.index]
	end 
	end 
function Atlas:getMap() return self.maps[ self.index ] end

function Atlas:toggleVisible()
	if not self.maps[ self.index ] then return end
	if self.maps[ self.index ].kind == "scenario" then return end -- a scenario is never displayed to the players
	if self.visible == self.index then 
		self.visible = nil 
		-- erase snapshot !
		currentImage = nil 
	  	-- send hide command to projector
		udp:send("HIDE")
	else    
		self.visible = self.index 
		-- change snapshot !
		currentImage = self.maps[ self.index ].im
		-- send to projector
		sendOver( self.maps[ self.index ] )
	end
	end

function Atlas:removeVisible()
	self.visible = nil
	end

function Atlas:isVisible(map)
	local idx = nil 
	for k,v in pairs(self.maps) do if v == map then idx = k end end
	return self.visible == idx
	end

function Atlas.new() 
  local new = {}
  setmetatable(new,Atlas)
  new.maps = {}
  new.visible = nil -- index of the map currently visible (or nil if none)
  new.index = 0 -- index of the current map with focus in map mode (or 0 if none) 
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


-- return the 1st character of a class, or nil if not found
function findPNJByClass( class )
  if not class then return nil end
  for i=1,PNJnum-1 do if PNJTable[i].class == class then return i end end
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


function love.keypressed( key, isrepeat )

  --
  -- IN COMBAT MODE
  --
  if Mode == "combat" then

   -- display PJ snapshots or not
   if key == "s" then displayPJSnapshots = not displayPJSnapshots end

   -- UP and DOWN change focus to previous/next PNJ
   if key == "down" then
    if not focus then return end
    if focus < PNJnum-1 then 
      lastFocus = focus
      focus = focus + 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
    return
   end
  
   if key == "up" then
    if not focus then return end
    if focus > 1 then 
      lastFocus = focus
      focus = focus - 1
      focusAttackers = PNJTable[ focus ].attackers
      focusTarget  = PNJTable[ focus ].target
    end
    return
   end

   if key == "escape" then
	Mode = "map"  -- switch to scenario/map mode
   end
 
  --
  -- IN MAP MODE
  --
 elseif Mode == "map" then

   local map = atlas:getMap() 

   if map then

   	if key == "escape" then
	  map = atlas:nextMap()
	  if not map then	
	    Mode = "combat"	   
	    -- reset search input
	    searchActive = false
	    text = textBase 
	  end
   	end
 
   if key == "up" then
	map.y = map.y - map.step * map.mag 
	if map.y < 0 then map.y = 0 end
	if atlas:isVisible(map) then udp:send("CHXY " .. map.x .. " " .. map.y ) end
   end 

   if key == "down" then
	map.y = map.y + map.step * map.mag 
	local _,max = map.im:getDimensions()
	if map.y > max then map.y = max end
	if atlas:isVisible(map) then udp:send("CHXY " .. map.x .. " " .. map.y ) end
   end 

   if key == "right" then
	map.x = map.x + map.step * map.mag 
	local max,_ = map.im:getDimensions()
	if map.x > max then map.x = max end
	if atlas:isVisible(map) then udp:send("CHXY " .. map.x .. " " .. map.y ) end
   end 

   if key == "left" then
	map.x = map.x - map.step * map.mag 
	if map.x < 0 then map.x = 0 end
	if atlas:isVisible(map) then udp:send("CHXY " .. map.x .. " " .. map.y ) end
   end 

   if key == keyZoomIn then
	if map.mag >= 1 then map.mag = map.mag + 1 end
	if map.mag < 1 then map.mag = map.mag + 0.5 end	
	ignoreLastChar = true
	if atlas:isVisible(map) then udp:send("MAGN " .. 1/map.mag ) end	
   end 

   if key == keyZoomOut then
	if map.mag > 1 then 
		map.mag = map.mag - 1 
	elseif map.mag <= 1 then 
		map.mag = map.mag - 0.5 
	end	
	if map.mag == 0 then map.mag = 0.5 end
	ignoreLastChar = true
	if atlas:isVisible(map) then udp:send("MAGN " .. 1/map.mag ) end	
   end 

   if key == "v" and map.kind == "map" then
	atlas:toggleVisible()
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

	if map.kind == "scenario" then

	  if searchIterator then
		map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator()
	  end

	elseif map.kind == "map" then

	  -- switch between rectangles and circles
	  if arrowModeMap == "RECT" then arrowModeMap = "CIRC" else arrowModeMap = "RECT" end

	end

   end

   if key == "return" then
	  searchIterator = doSearch( string.gsub( text, textBase, "" , 1) )
	  text = textBase
	  if searchIterator then
		map.x,map.y,searchPertinence,searchIndex,searchSize = searchIterator()
	  end
   end

   end -- if map then

 end 
    
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
        yui.Text({name="class",text="", w=width*2.5, bold=1, size=size, center=1}),
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

--
-- Main function
-- Load PNJ class file, print (empty) GUI, then go on
--
  function love.load( args )

    -- GUI initializations...
    yui.UI.registerEvents()
    love.window.setTitle( "Fading Suns Combat Tracker" )

    -- log file
    logFile = io.open("fading.log","w")
    io.output(logFile)

    -- adjust number of rows in screen
    PNJmax = math.floor( viewh / 42 )

    -- some adjustments on different systems
    if love.system.getOS() == "Windows" then

    	W, H = love.window.getDesktopDimensions()
    	W, H = W * 0.96, H * 0.90
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
    
    -- load dice images
    diceB = {} 
    diceB[1] = love.graphics.newImage( 'dice/b1.png' )
    diceB[2] = love.graphics.newImage( 'dice/b2.png' )
    diceB[3] = love.graphics.newImage( 'dice/b3.png' )
    diceB[4] = love.graphics.newImage( 'dice/b4.png' )
    diceB[5] = love.graphics.newImage( 'dice/b5.png' )
    diceB[6] = love.graphics.newImage( 'dice/b6.png' )

    diceW = {} 
    diceW[1] = love.graphics.newImage( 'dice/w1.png' )
    diceW[2] = love.graphics.newImage( 'dice/w2.png' )
    diceW[3] = love.graphics.newImage( 'dice/w3.png' )
    diceW[4] = love.graphics.newImage( 'dice/w4.png' )
    diceW[5] = love.graphics.newImage( 'dice/w5.png' )
    diceW[6] = love.graphics.newImage( 'dice/w6.png' )


    -- create view structure
    love.graphics.setBackgroundColor( 248, 245, 244 )
    view = yui.View(0, 0, W, viewh, {
        margin_top = 5,
        margin_left = 5,
        --yui.Flow({name="tabs",
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
    
    -- create socket and connect to the client
    udp = socket.udp()
    udp:settimeout(0)
    udp:setpeername(address, port)

    -- some initialization stuff
    generateUID = UIDiterator()

    -- create PJ automatically (1 instance of each!)
    -- later on, an image might be attached to them, if we find one
    createPJ()

    -- get images & scenario directory, either provided at command line or default one
    local fadingDirectory = args[ 2 ] 
    local sep = '/'
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
    io.write("directory : |" .. fadingDirectory .. "|\n")

    -- list all files in that directory, by executing a command ls or dir
    local allfiles = {}, command
    if love.system.getOS() == "OS X" then
	    io.write("ls '" .. fadingDirectory .. "' > .temp\n")
	    os.execute("ls '" .. fadingDirectory .. "' > .temp")
    elseif love.system.getOS() == "Windows" then
	    io.write("dir /b \"" .. fadingDirectory .. "\" > .temp\n")
	    os.execute("dir /b \"" .. fadingDirectory .. "\" > .temp ")
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
      --   PJ IMAGE:		PJ_pjname.jpg, they are considered as images for corresponding PJ
      --   SNAPSHOTS:		*.jpg or *.png, all are snapshots displayed at the bottom part
      --
      if f == 'scenario.txt' then 
	      readScenario( fadingDirectory .. sep .. f ) 
	      io.write("Loaded scenario at " .. fadingDirectory .. sep .. f .. "\n")
	      scenarioTextNum = scenarioTextNum + 1
      end

      if f == 'scenario.jpg' then

	atlas:addMap( Map.new( "scenario", fadingDirectory .. sep .. f ) )
	io.write("Loaded scenario image file at " .. fadingDirectory .. sep .. f .. "\n")
	scenarioImageNum = scenarioImageNum + 1

      elseif string.sub(f,-4) == '.jpg' or string.sub(f,-4) == '.png'  then

        if string.sub(f,1,3) == 'PJ_' then

		local pjname = string.sub(f,4, f:len() - 4 )
		io.write("Looking for PJ " .. pjname .. "\n")
		local index = findPNJByClass( pjname ) 
		if index then
			PNJTable[index].snapshot = loadSnap( fadingDirectory .. sep .. f )  
			PJImageNum = PJImageNum + 1
		end

	elseif string.sub(f,1,3) == 'map' then

	  atlas:addMap( Map.new( "map", fadingDirectory .. sep .. f ) )
	  mapsNum = mapsNum + 1

 	else

	  table.insert( snapshots, loadSnap( fadingDirectory .. sep .. f ) ) 
	  
        end

      end

    end

    io.write("Loaded " .. #snapshots .. " snapshots, " .. mapsNum .. " maps, " .. PJImageNum .. " PJ images, " .. scenarioImageNum .. " scenario image, " .. 
    		scenarioTextNum .. " scenario text\n" )
 
  end



