--
-- Fading Suns Mobile
--

local widget = require( "widget" )
local socket = require( "socket" )
local composer = require( "composer" )

require ("connect")

-- create socket for server communication
tcp = socket.tcp()
tcp:settimeout(2)

-- udp for getting our own ip address
udp = socket.udp()
udp:settimeout(0)

-- Hide status bar
display.setStatusBar( display.HiddenStatusBar )
 
-- Seed the random number generator
math.randomseed( os.time() )
 
myIP = function()
    local s = socket.udp()  --creates a UDP object
    s:setpeername( "74.125.115.104", 80 )  --Google website
    local ip, sock = s:getsockname()
    s:close()
    return ip
end

-- listen on a transient port
tcp:bind( myIP() , 0)
local i,p = tcp:getsockname()
print("i,p=" .. tostring(i) .. " " .. tostring(p) )


local function listenForServer()
  if is_connected then
  	local data , msg = tcp:receive()
  	if data then answerValue = "> " .. data .. "\n" .. answerValue end
	--if answerField then answerField.text = answerValue end
	Runtime:dispatchEvent( { name = "messageReceived", target = answerValue } )
  end
  end

Runtime:addEventListener( "enterFrame", listenForServer )

-- Go to the menu screen
composer.gotoScene( "menu" )

--[[
-- Predefine display objects for use later
local ipField, portField, messageField, answerField
local fields = display.newGroup()

local configure = true 

display.setDefault( "background", 80/255 )

-- create socket for server communication
local tcp = socket.tcp()
tcp:settimeout(2)

-- udp for getting our own ip address
udp = socket.udp()
udp:settimeout(0)

local is_connected = false
local serverip, serverport = nil, nil

local limitLeft = 20
local limitRight = 20

-- send function
local function tcpsend()
  
    -- get user's input
  local message = messageField.text
  
  -- clean message text
  messageField.text = ""
  
  -- connect to server using user's input   
  local ip = ipField.text
  local port = portField.text
  
  -- check if something changed. In that case we reconnect
  if is_connected and ((serverip ~= ip) or (serverport ~= port)) then is_connected = false end
  
  -- connect to server. Store connection information to avoid
  -- further reconnection
  local success, msg
  if not is_connected then
    local success, msg = tcp:connect(ip, port)
    tcp:settimeout(0)
    print("tcp connect to " .. ip .. " , " .. port .. " : " .. tostring(success) .. ", msg=" .. tostring(msg))
    if not success then 
	answerField.text =  "! error : Cannot connect to " .. ip .. ":" .. port .. "\n" .. answerField.text
	return 
     end
    is_connected = true
    serverip = ip
    serverport = port
  end
  
  success, msg = tcp:send( message .. "\n" )
  print("send message: " .. tostring(success) .. ", msg=" .. tostring(msg))
  
  -- add message to textbox
  answerField.text =  "moi: " .. message .. "\n" .. answerField.text
  
end

-------------------------------------------
-- *** Add field labels ***
-------------------------------------------

display.setDefault( "anchorX", 0.0 )	-- default to TopLeft anchor point for new objects
display.setDefault( "anchorY", 0.0 )

local fsLabel = display.newText( "Fadings Suns", 100, 0, native.systemFont, 20 )
fsLabel:setFillColor( 150/255, 150/255, 1 )

local ipLabel = display.newText( "IP", 70, 20, native.systemFont, 14 )
ipLabel:setFillColor( 150/255, 150/255, 1 )

local portLabel = display.newText( "Port", 200, 20, native.systemFont, 14 )
portLabel:setFillColor( 150/255, 150/255, 1 )

local mLabel = display.newText( "Your message", 10, 80, native.systemFont, 18 )
mLabel:setFillColor( 150/255, 150/255, 1 )


-------------------------------------------
-- *** Buttons Presses ***
-------------------------------------------

-- Default Button Pressed
local sendButtonPress = function( event )
  if messageField.text ~= "" then tcpsend() end
end

local configurePress = function( event )
  configure = not configure
  if configure then
	fsLabel.y = 0
	mLabel.y = 80
	ipLabel.y = 20
	portLabel.y = 20
 	ipField.y = 45
	portField.y = 45 	
	messageField.y = 105
	answerField.y = 155 
	answerField.height = 268
  else
	mLabel.y = 15 
	fsLabel.y = -100 
	ipLabel.y = 1000
 	ipField.y = 1000 
	portField.y = -100 	
	portLabel.y = -100 
	messageField.y = 40 
	answerField.y = 90  
	answerField.height = 268 + 65 
  end 
end

-------------------------------------------
-- *** Create native input textfields ***
-------------------------------------------

ipField = native.newTextField( 10, 45, 150, 30 )
ipField:addEventListener( "userInput", fieldHandler( function() return ipField end ) ) 
ipField.placeholder = "192.168.0.1"

portField = native.newTextField( 170, 45, 100, 30 )
portField.inputType = "number"
portField:addEventListener( "userInput", fieldHandler( function() return portField end ) ) 
portField.text = "12345"

messageField = native.newTextField( 10, 105, 290, 35 )
messageField:addEventListener( "userInput", fieldHandler( function() return messageField end ) ) 

answerField = native.newTextBox( 10, 155, 290 , 268)
--answerField.font = font

-- Add fields to our new group
fields:insert(ipField)
fields:insert(portField)
fields:insert(messageField)
fields:insert(answerField)

-------------------------------------------
-- *** Create Buttons ***
-------------------------------------------
-- You could also assign different handlers for each textfield


-- "Remove Default" Button
defaultButton = widget.newButton
{
	defaultFile = "buttonBlue.png",
	overFile = "buttonBlueOver.png",
	label = "Send",
	labelColor = 
	{ 
		default = { 1, 1, 1 }, 
	},
	fontSize = 18,
	emboss = true,
	onPress = sendButtonPress,
}

confButton = widget.newButton
{
	defaultFile = "buttonBlueSmall.png",
	overFile = "buttonBlueOverSmall.png",
	label = "configure",
	labelColor = 
	{ 
		default = { 1, 1, 1 }, 
	},
	fontSize = 10,
	emboss = true,
	onPress = configurePress,
}


-- Position the buttons on screen
defaultButton.x = display.contentCenterX - defaultButton.contentWidth/2;	defaultButton.y = 420
confButton.x = display.contentCenterX - confButton.contentWidth/2; confButton.y = 475 

-------------------------------------------
-- Create a Background touch event
-------------------------------------------

local bkgd = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
bkgd:setFillColor( 0, 0, 0, 0 )		-- set Alpha = 0 so it doesn't cover up our buttons/fields


local listener = function( event )
	native.setKeyboardFocus( nil )
	return true
end

-- Add listener to background for user "tap"
bkgd:addEventListener( "tap", listener )


local myIP = function()
    local s = socket.udp()  --creates a UDP object
    s:setpeername( "74.125.115.104", 80 )  --Google website
    local ip, sock = s:getsockname()
    s:close()
    return ip
end


-- listen on a transient port
tcp:bind( myIP() , 0)
local i,p = tcp:getsockname()
print("i,p=" .. tostring(i) .. " " .. tostring(p) )


local function listenForServer()
  if is_connected then
  	local data , msg = tcp:receive()
  	if data then answerField.text = data .. "\n" .. answerField.text end
  end
  end

-- Frame update listener
Runtime:addEventListener( "enterFrame", listenForServer )

]]

