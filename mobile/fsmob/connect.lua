
serverip, serverport, serveruser = nil, 12345, nil
is_connected = false
texts = {}

-- list of available colors, one per calling user
colors = {{255,255,255},{204,255,255},{204,255,204},{204,255,153},{153,204,255}}

-- list of current callers, each one is = { name = string , color = index }
-- if name == "", caller = self
callers = { { name = "", color = 1 } , { name = "MJ" , color = 2 } }
nextColor = 3

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
  end
  
  success, msg = tcp:send( message .. "\n" )
  print("send message: " .. tostring(success) .. ", msg=" .. tostring(msg))
  
  if success then return true else return false end

end
  
