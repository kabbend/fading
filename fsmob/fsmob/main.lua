--
-- Fading Suns Mobile
--

local widget = require( "widget" )
local socket = require( "socket" )

-- Predefine display objects for use later
local ipField, portField, messageField, answerField
local fields = display.newGroup()

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

--[[
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
--]]

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
    if not success then return end
    is_connected = true
    serverip = ip
    serverport = port
  end
  
  success, msg = tcp:send( message .. "\n" )
  print("send message: " .. tostring(success) .. ", msg=" .. tostring(msg))
  
  -- add message to textbox
  answerField.text =  "moi: " .. message .. "\n" .. answerField.text
  
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

ipField = native.newTextField( 10, 50, 150, 30 )
ipField:addEventListener( "userInput", fieldHandler( function() return ipField end ) ) 
ipField.placeholder = "192.168.0.1"

portField = native.newTextField( 170, 50, 100, 30 )
portField.inputType = "number"
portField:addEventListener( "userInput", fieldHandler( function() return portField end ) ) 
portField.text = "12345"

messageField = native.newTextField( 10, 110, 290, 35 )
messageField:addEventListener( "userInput", fieldHandler( function() return messageField end ) ) 

answerField = native.newTextBox( 10, 160, 290 , 250)
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
--local defaultLabel = display.newText( "Mobile App", 110, 25, native.systemFont, 20 )
--defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "IP", 70, 25, native.systemFont, 14 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "Port", 200, 25, native.systemFont, 14 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

local defaultLabel = display.newText( "Your message", 10, 85, native.systemFont, 18 )
defaultLabel:setFillColor( 150/255, 150/255, 1 )

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



