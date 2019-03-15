
local widget = require( "widget" )
local composer = require( "composer" )
local json = require( "json" )
require("connect")

local scene = composer.newScene()
local currentGroup = display.newGroup()

local messageField

local function applyMessage(event)
	-- if message received, it is stored in global texts[] array. just redraw scene
	scene:show( { phase = "did" } )
end

local function send()

  local text = messageField.text
  local ret = tcpsend( text )
  if ret then
	table.insert( texts , { t = text , caller = "" } ) -- from me
  	messageField.text = ""
	scene:show( { phase = "did" } )
  else
  	messageField.text = ""
	table.insert( texts , { t = "(an error occurred. Check connection)" , caller = "" } ) -- from me
	scene:show( { phase = "did" } )
  end
end


local function fieldHandler( textField )
	return function( event )
		if ( "began" == event.phase ) then
			-- This is the "keyboard has appeared" event
			-- In some cases you may want to adjust the interface when the keyboard appears.
		
		elseif ( "ended" == event.phase ) then
			-- This event is called when the user stops editing a field: for example, when they touch a different field
			
		elseif ( "editing" == event.phase ) then
		
		elseif ( "submitted" == event.phase ) then
			-- This event occurs when the user presses the "return" key (if available) on the onscreen keyboard
			send()
			-- Hide keyboard
			native.setKeyboardFocus( nil )
		end
	end
end

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local function gotoMenu()
	composer.gotoScene( "menu" )
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view

	local background = display.newImageRect( sceneGroup, "background.png", 800, 1400 )
	background.x = display.contentCenterX
	background.y = display.contentCenterY

	local fsLabel = display.newText( sceneGroup, "Your message", 80, 0, native.systemFont, 20 )
	fsLabel:setFillColor( 1, 1, 1 )

	messageField = native.newTextField( display.contentCenterX, 35, 280, 35 )
	messageField.size = 18 
	messageField:addEventListener( "userInput", fieldHandler( function() return messageField end ) )

	Runtime:addEventListener( "messageReceived", applyMessage )

	sceneGroup:insert( messageField )

	local menuButton = display.newText( sceneGroup, "Return to Menu", display.contentCenterX, 700, native.systemFont, 32 )
	menuButton.x = display.contentCenterX 
	menuButton.y = 470 
	menuButton:setFillColor( 1, 1, 1 )
	menuButton:addEventListener( "tap", gotoMenu )

end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		-- print all messages in reverse order (the latest one first, on top of screen)
		local y = 0 
		local w = widget.newScrollView({x=15,y=70,width=300,height=380,hideBackground=true,horizontalScrollDisabled=true})
		w.anchorX , w.anchorY = 0, 0
		local newGroup = display.newGroup()
		newGroup.anchorX , newGroup.anchorY = 0, 0
		newGroup.x = 0 
		currentGroup:removeSelf()
		for i=#texts,1,-1 do
			
			-- get text to display
			local text = texts[i].t
			if texts[i].caller and texts[i].caller ~= "" then
				text = texts[i].caller .. " : " .. text
			end

			-- get alignment
			local align , x
			if texts[i].caller == "" then 
				align = "left" 
				x = 10
				
			else 
				align = "right" 
				x = 90 
			end

			-- create a dummy text just to get actual width
			local t_temp = display.newText ( { text  = text , y = y , height = 0, align = align , x = x } )
			local actual_width = t_temp.width
			t_temp:removeSelf()

			-- now create the same text, with wrapping limit
			local t = display.newText ( { text  = text , y = y , width = 195 , height = 0, align = align , x = x } )
			t.anchorX , t.anchorY = 0, 0
			t:setFillColor( 0, 0, 0 )

			-- the rectangle will have the appropriate width and alignement
			local rect_width = math.min( actual_width , t.width )
			if align == "right" then x = x + (195 - rect_width) end  -- go right if needed 
			local r = display.newRoundedRect( x - 2 , y - 2 , rect_width + 2 , t.height + 2 , 3 )
			
			-- find caller and color
			local col = { 0, 0, 0 }
			for j=1,#callers do
				if callers[j].name == texts[i].caller then col = colors[j] ; break end
			end
			r:setFillColor( col[1] / 255 , col[2] / 255 , col[3] / 255 )
			r.anchorX , r.anchorY = 0, 0

			-- insert text and rectangle
			newGroup:insert( r )
			newGroup:insert( t )
			t:toFront()

			y = y + t.height + 7 
			if y > 1000 then break end
		end
		currentGroup = newGroup
		w:insert( newGroup )
		sceneGroup:insert( w )
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener( "messageReceived" , applyMessage )
		currentGroup:removeSelf()
		local previous = composer.getSceneName("previous")
          	composer.removeScene(previous)

	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene


