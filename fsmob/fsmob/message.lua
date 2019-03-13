
local widget = require( "widget" )
local composer = require( "composer" )
require("connect")

local scene = composer.newScene()
local currentGroup = display.newGroup()

local messageField

local function applyMessage(event)
	scene:show( { phase = "did" } )
end

local function send()
  local ret = tcpsend( messageField.text )
  if ret then	
	table.insert( texts , { t = "moi: " .. messageField.text, fromMe = true } )
  	messageField.text = ""
	scene:show( { phase = "did" } )
  else
  	messageField.text = ""
	table.insert( texts , { t = "(an error occurred. Check connection)" , fromMe = true } )
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
			local text = texts[i].t
			local align , x
			if texts[i].fromMe then 
				align = "left" 
				x = 10
				
			else 
				align = "right" 
				x = 90 
			end
			local t = display.newText ( { text  = text , x = 0 , y = y , width = 195 , height = 0, align = align , x = x } )
			t.anchorX , t.anchorY = 0, 0
			newGroup:insert( t )
			y = y + t.height + 5 
			--if y > 420 then break end
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


