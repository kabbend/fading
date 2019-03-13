
local widget = require( "widget" )
local composer = require( "composer" )
require("connect")

local scene = composer.newScene()

local messageField
local answerField =  native.newTextBox( display.contentCenterX, 250, 280 , 360)
answerField.size = 16 

local function applyMessage(event)
	answerField.text = answerValue
end

local function send()
  local ret = tcpsend( messageField.text )
  if ret then	
  	answerValue = "> moi: " .. messageField.text .. "\n" .. answerValue 
  	messageField.text = ""
  	answerField.text = answerValue
  else
  	messageField.text = ""
	answerValue = "(an error occurred. Check connection)\n" .. answerValue
  	answerField.text = answerValue
  end
end


local function fieldHandler( textField )
	return function( event )
		if ( "began" == event.phase ) then
			-- This is the "keyboard has appeared" event
			-- In some cases you may want to adjust the interface when the keyboard appears.
		
		elseif ( "ended" == event.phase ) then
			-- This event is called when the user stops editing a field: for example, when they touch a different field
			--send()
			
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

	if answerValue then answerField.text = answerValue end

	Runtime:addEventListener( "messageReceived", applyMessage )

	sceneGroup:insert( messageField )
	sceneGroup:insert( answerField )

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


