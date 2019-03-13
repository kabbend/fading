
ipField, portField, userField =  nil, nil, nil
serverip, serverport, serveruser = nil, nil, nil
is_connected = false
texts = {}
--answerValue = ""

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


-- send function
function tcpsend(message)
  
  -- connect to server using user's input   
  local ip = serverip 
  local port = serverport 

  if not ip or not port or (ip == "" or port == "") then return false end
 
  -- connect to server. Store connection information to avoid
  -- further reconnection
  local success, msg
  if not is_connected then
    local success, msg = tcp:connect(ip, port)
    tcp:settimeout(0)
    print("tcp connect to " .. ip .. " , " .. port .. " : " .. tostring(success) .. ", msg=" .. tostring(msg))
    if not success then 
	return false
     end
    is_connected = true
    serverip = ip
    serverport = port
  end
  
  success, msg = tcp:send( message .. "\n" )
  print("send message: " .. tostring(success) .. ", msg=" .. tostring(msg))
  
  if success then return true else return false end

end
  
