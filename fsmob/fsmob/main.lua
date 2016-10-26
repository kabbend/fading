--
-- Fading Suns Mobile
--

local widget = require( "widget" )
local socket = require( "socket" )

-- Predefine display objects for use later
local ipField, portField, messageField, answerField
local fields = display.newGroup()

display.setDefault( "background", 80/255 )

-- create socket 
local tcp = socket.tcp()
tcp:settimeout(2)

udp = socket.udp()
udp:settimeout(0)

local is_connected = false
local serverip, serverport = nil, nil

local limitLeft = 20
local limitRight = 20

-- return a text aligned on the left (player)
local function formatLeft( text )
  local newtext = ""
  local column = 1
  for i=1,string.len(text) do
    local char = string.sub( text, i, i)
    if char == " " and column >= limitLeft then
      column = 1
      newtext = newtext .. "\n"
    else
      column = column + 1
      newtext = newtext .. char
    end
  end
  newtext = newtext .. "\n\n"
  return newtext
end

-- return a text aligned on the right (MJ)
local function formatRight( text )
  local newtext = ""
  local line = ""
  --local column = 1
  local i = 1
  while line do
    
    local word = ""
    while string.sub(text,i,i) == " " and i <= string.len(text) do i = i + 1 end -- eat spaces
    while string.sub( text, i,i) ~= " " and i <= string.len(text) do word = word .. string.sub( text, i,i); i = i + 1 end -- get next word
    if word == "" then -- no more word...
      if line ~= "" then -- treat last line if any
        --local col = math.max( limitRight, 45 - string.len(line))
        for j=1,limitRight do newtext = newtext .. " " end
        newtext = newtext .. line .. "\n"
      end
      line = nil -- stop loop
    else
      if string.len(line) + string.len(word) <= 24 then
        line = line .. " " .. word
      else
        --local col = math.max( limitRight, 45 - string.len(line))
        for j=1,limitRight do newtext = newtext .. " " end
        newtext = newtext .. line .. "\n"
        line = word
      end
    end
    
  end
  newtext = newtext .. "\n"
  return newtext
end

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
  if is_connected and ((serverip ~= ip) or (serverport ~= port)) then
    is_connected = false
  end
  
  -- connect to server. Store connection information to avoid
  -- further reconnection
  local success, msg
  if not is_connected then
    local success, msg = tcp:connect(ip, port)
    print("tcp connect to " .. ip .. " , " .. port .. " : " .. tostring(success) .. ", msg=" .. tostring(msg))
    --success, msg = tcp:setpeername(ip, port)
    if not success then return end
    is_connected = true
    serverip = ip
    serverport = port
  end
  
  --answerField.text =  answerField.text .. "connecting to " .. ip .. ":" .. port .. ",message " .. tostring(mesg).. "\n"
  
  success, msg = tcp:send( message .. "\n" )
  print("send message: " .. tostring(success) .. ", msg=" .. tostring(msg))
  
  -- add message to textbox
  answerField.text =  answerField.text .. "moi: " .. formatLeft(message)
  
  --answerField.text = answerField.text .. formatRight( "MJ: ceci est un petit test pour vérifier ce qui se passe" )
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
			tcpsend()
			
			-- Hide keyboard
			native.setKeyboardFocus( nil )
		end
	end
end


-------------------------------------------
-- *** Buttons Presses ***
-------------------------------------------

-- Default Button Pressed
local sendButtonPress = function( event )
  if messageField.text ~= "" then tcpsend() end
end

-------------------------------------------
-- *** Create native input textfields ***
-------------------------------------------

display.setDefault( "anchorX", 0.0 )	-- default to TopLeft anchor point for new objects
display.setDefault( "anchorY", 0.0 )

ipField = native.newTextField( 10, 60, 180, 30 )
ipField:addEventListener( "userInput", fieldHandler( function() return ipField end ) ) 
ipField.placeholder = "192.168.0.1"

portField = native.newTextField( 10, 100, 180, 30 )
portField.inputType = "number"
portField:addEventListener( "userInput", fieldHandler( function() return portField end ) ) 
portField.text = "12345"

messageField = native.newTextField( 10, 175, 290, 35 )
messageField:addEventListener( "userInput", fieldHandler( function() return messageField end ) ) 

answerField = native.newTextBox( 10, 215, 290 , 190)
--answerField.font = font

-- Add fields to our new group
fields:insert(ipField)
fields:insert(portField)
fields:insert(messageField)
fields:insert(answerField)

-------------------------------------------
-- *** Add field labels ***
-------------------------------------------

local defaultLabel = display.newText( "Fadings Suns", 100, 5, native.systemFont, 20 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )
local defaultLabel = display.newText( "Mobile App", 110, 25, native.systemFont, 20 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "IP", 200, 60, native.systemFont, 18 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "Port", 200, 100, native.systemFont, 18 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "Message", 10, 140, native.systemFont, 18 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

--display.setDefault( "anchorX", 0.5 )	-- restore anchor points for new objects to center anchor point
--display.setDefault( "anchorY", 0.5 )

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


-- Position the buttons on screen
defaultButton.x = display.contentCenterX - defaultButton.contentWidth/2;	defaultButton.y = 425

-------------------------------------------
-- Create a Background touch event
-------------------------------------------

local bkgd = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
bkgd:setFillColor( 0, 0, 0, 0 )		-- set Alpha = 0 so it doesn't cover up our buttons/fields

-- Tapping screen dismisses the keyboard
--
-- Needed for the Number and Phone textFields since there is
-- no return key to clear focus.

local listener = function( event )
	-- Hide keyboard
	--print("tap pressed")
	native.setKeyboardFocus( nil )
	
	return true
end

-- Add listener to background for user "tap"
bkgd:addEventListener( "tap", listener )


local myIP = function()
    local s = socket.udp()  --creates a UDP object
    s:setpeername( "74.125.115.104", 80 )  --Google website
    local ip, sock = s:getsockname()
    --answerField.text = answerField.text .. "myIP:"..ip..":"..sock.."\n"
    s:close()
    return ip
end


-- listen on a transient port
tcp:bind( myIP() , 0)
local i,p = tcp:getsockname()
print("i,p=" .. tostring(i) .. " " .. tostring(p) )
--answerField.text = answerField.text .. "Listening on " .. i .. " " .. p .. "\n"


local function listenForServer()
  local data , msg = udp:receive()
  --socket.sleep(0.1)
  if data and data ~="" then
    answerField.text = answerField.text .. formatRight( "MJ:" .. data )
  end
end

-- Frame update listener
Runtime:addEventListener( "enterFrame", listenForServer )



