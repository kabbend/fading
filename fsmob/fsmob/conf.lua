
local widget = require( "widget" )
local composer = require( "composer" )
local socket = require( "socket" )

require("connect")

local scene = composer.newScene()

local returnLabel = nil

local function connect()
  print("trying connect")
  returnLabel.text = ""
  serverip, serverport, serveruser = ipField.text, portField.text, userField.text
  local ret = tcpsend( userField.text ) 
  if not ret then
	returnLabel.text = "Connection refused"
	-- reset transient port for next connection attempt
	tcp:close()
	tcp = socket.tcp()
	tcp:settimeout(2)
	tcp:bind( myIP() , 0)
	local i,p = tcp:getsockname()
	print("i,p=" .. tostring(i) .. " " .. tostring(p) )
  else
	returnLabel.text = "Connection OK"
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
			--tcpsend()
			
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

	--display.setDefault( "anchorX", 0.0 )    -- default to TopLeft anchor point for new objects
	--display.setDefault( "anchorY", 0.0 )

	-- Code here runs when the scene is first created but has not yet appeared on screen

	local fsLabel = display.newText( sceneGroup, "Configure connection to server", display.contentCenterX, 5, native.systemFont, 20 )
	fsLabel:setFillColor( 1, 1, 1 )

	local ipLabel = display.newText( sceneGroup, "Server IP", 90, 45, native.systemFont, 16 )
	ipLabel:setFillColor( 1, 1, 1 )

	local portLabel = display.newText( sceneGroup, "Port", 250, 45, native.systemFont, 16 )
	portLabel:setFillColor( 1, 1, 1 )

	local userLabel = display.newText( sceneGroup, "Username", display.contentCenterX, 120, native.systemFont, 16 )
	userLabel:setFillColor( 1, 1, 1 )

	returnLabel = display.newText( sceneGroup, "", display.contentCenterX, 250, native.systemFont, 16 )
	returnLabel:setFillColor( 1, 1, 1 )

	ipField = native.newTextField( 100, 80, 160, 30 )
	ipField:addEventListener( "userInput", fieldHandler( function() return ipField end ) ) 
	ipField.text = "192.168.1.20"
	if serverip then ipField.text = serverip end

	portField = native.newTextField( 250, 80, 100, 30 )
	portField.inputType = "number"
	portField:addEventListener( "userInput", fieldHandler( function() return portField end ) ) 
	portField.text = "12345"
	if serverport then portField.text = serverport end

	userField = native.newTextField( 150, 160, 200, 30 )
	userField:addEventListener( "userInput", fieldHandler( function() return userField end ) ) 
	userField.placeholder = "user"
	if serveruser then userField.text = serveruser end

	local testButton = widget.newButton
	{
	defaultFile = "buttonBlue.png",
	overFile = "buttonBlueOver.png",
	label = "Connect",
	labelColor = { default = { 1, 1, 1 }, },
	fontSize = 18,
	emboss = true,
	onPress = connect,
	}

	testButton.x = display.contentCenterX
	testButton.y = 350 

	sceneGroup:insert( testButton )
	sceneGroup:insert( ipField )
	sceneGroup:insert( portField )
	sceneGroup:insert( userField )

	--local title = display.newImageRect( sceneGroup, "title.png", 500, 80 )
	--title.x = display.contentCenterX
	--title.y = 200

	local menuButton = display.newText( sceneGroup, "Return to Menu", display.contentCenterX, 700, native.systemFont, 32 )
	menuButton.x = display.contentCenterX 
	menuButton.y = 470 
	menuButton:setFillColor( 1, 1, 1 )
	menuButton:addEventListener( "tap", gotoMenu )
	--testButton:addEventListener( "onPress", connect )

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


