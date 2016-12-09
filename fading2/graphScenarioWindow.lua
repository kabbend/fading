
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	-- widgets components
local Snapshot		= require 'snapshotClass'-- widgets components
local SLAXML 		= require 'slaxml'	-- XML parser
local GraphLibrary 	= require('graph').Graph

local graph = GraphLibrary.new()

local translation 	= false		-- are we currently translating within the window ?
local nodeMove 		= nil		-- are we currently moving a node ? If yes, points to the node, nil otherwise 
local fonts 		= {}		-- same font with different sizes

local MAX_TEXT_W_AT_SCALE_1	= 400
local BIGGER_SHARP		= 2
local BIGGER_2_SHARP		= 1.6
local BIGGER_3_SHARP		= 1.3
local ALIGN 			= "left"

--
-- graphScenarioWindow class
--
local graphScenarioWindow = Window:new{ class = "graph" , wResizable = true, hResizable = true , movable = true }

function graphScenarioWindow:new( t ) -- create from w, h, x, y, filename
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.offsetX, new.offsetY = 0, 0	-- this offset is applied each time we manipulate nodes, it represents the translation
					-- we do with the mouse within the window
  new:loadGraph(t.filename)		-- load XML file
  new.z = 1.0				-- zoom factor
  for i=4,40 do 			-- load same font with different sizes
    fonts[i] = love.graphics.newFont( "yui/yaoui/fonts/georgia.ttf" , i ) 
  end
  return new
end

function graphScenarioWindow:zoom(v)
  if v < 0 then v = -0.02 else v = 0.02 end 
  self.z = self.z + v
  if self.z <= 0.02 then self.z = 0.02 end
  if self.z >= 5 then self.z = 5 end 
  end

-- load an image from Internet
local function loadimage(url,size)
  -- load and check result
  local http = require("socket.http")
  local b, c = http.request( url )
  io.write("downloading " .. url .. " HTTP status = " .. tostring(c) .. ", " .. string.len(tostring(b)) .. " bytes\n")
  if (not b) or (c ~= 200) then return nil end

  -- write it to a file
  local filename = ".localtmpimage"
  local f = io.open(filename,"wb")
  if not f then return nil end
  f:write(b)
  f:close()

  -- store the content of the file to a snapshot
  local s = Snapshot:new{ filename = filename , size = size }
  return s 
  end

--
-- Load a scenario from a freemind.mm XML file
--
function graphScenarioWindow:loadGraph(filename)

  -- open XML file and read it completely (exit if no file)
  local xmlfile = io.open(filename)
  if not xmlfile then return end
  local myxml = xmlfile:read('*all')

  -- create the parser and appropriate callbacks
  local nodeID = {} 			-- stack to store current id at this level
  local id = 1 				-- incremental ID for the nodes, starting at 1
  local x,y,step = 0, 0, 10
  local currentID = nil			-- current id at this level
  local color = { 255, 0, 0 }

  local parser = SLAXML:parser{

    startElement = function(name,nsURI,nsPrefix) 
	if name == "node" then 
	  currentID = nodeID[#nodeID] 
	  table.insert(nodeID,id)
	end
        end, 

    attribute    = function(name,value,nsURI,nsPrefix) 
	if name == "COLOR" then
	  -- color is a string of the form '#rrggbb' with rr,gg,bb in hexadecimal
	  local r,g,b = string.sub(value,2,3), string.sub(value,4,5), string.sub(value,6,7)	
	  color = { "0x"..r, "0x"..g, "0x"..b }  
	end
	if name == "TEXT" then
	  local n
	  local a,b = string.find(value, "!%[uploaded image%]")
	  if a then
	    n = graph:addNode(tostring(id),"",x,y)
	    local _,_,url,w,h = string.find( string.sub(value,b+2), "(https?://.*[^ ]) (%d+)x(%d+)")
	    io.write("loading graph image : " .. tostring(url) .. "\n")
	    n.im = loadimage(url,w)
	  else
	    n = graph:addNode(tostring(id),value,x,y)
 	  end
	  n.color = color 
	  n.level = #nodeID
	  n.size = math.max(12 - #nodeID , 2)
  	  n:setMass(15/n.level)
	  -- create an edge 
	  if currentID then graph:connectIDs(tostring(currentID), tostring(id)) end 
	  id = id + 1
	  x,y = x + step, y + step
	end
	end, 

    closeElement = function(name,nsURI)
	if name == "node" then
	  table.remove(nodeID)   
        end
	end,

    -- unused callbacks, for the moment
    text         = function(text)                      end, -- text and CDATA nodes
    comment      = function(content)                   end, -- comments
    pi           = function(target,content)            end, -- processing instructions e.g. "<?yes mon?>"
  }

  -- parse file
  parser:parse(myxml,{stripWhitespace=true})

  -- center on the first node
  graph:getNode("1"):setPosition(self.w/2,self.h/2)
  graph:getNode("1"):setAnchor(true)

  end

function graphScenarioWindow:draw()

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)

  self:drawBack()
  self:drawBar()
  self:drawResize()
  
  love.graphics.setScissor(zx,zy,self.w,self.h)
  local function drawnode( node )
                local x, y = node:getPosition()
		x, y = x * self.z+self.offsetX, y * self.z+self.offsetY
		if x < 0 or x > self.w or y < 0 or y > self.h then return end
                if not node.im then
		  love.graphics.setColor(unpack(node.color))
		  love.graphics.circle( 'fill', zx+x, zy+y, node.size )
		else
		  love.graphics.setColor(255,255,255)
		  love.graphics.draw( node.im.im , zx+x, zy+y, 0, node.im.snapmag * self.z, node.im.snapmag * self.z )
		end
		local bigger = 1
		if string.sub(node.getName(),1,3) 	== "###" then 	bigger = BIGGER_3_SHARP 
		elseif string.sub(node.getName(),1,2) 	== "##" then 	bigger = BIGGER_2_SHARP 
		elseif string.sub(node.getName(),1,1)  	== "#" then 	bigger = BIGGER_SHARP 
		end
		if nodeMove == node then
		  -- the node with current focus is printed bigger
		  local fontSize = math.floor(12 * (node.size / 4) * bigger)
		  if fontSize < 4 then fontSize = 4 elseif fontSize > 40 then fontSize = 40 end
		  ALIGN = "left"
		  local xposition = 5  
		  -- if node is a leaf, the text direction is opposite to the edge direction (left or right)
		  if node.nConnected == 1 then
			local nx,ny = node.lastConnected:getPosition() 
			local ox,oy = node:getPosition() 
			if (ox - nx) < 0 then 
			  ALIGN = "right"
		  	  local width, wrappedtext = fonts[fontSize]:getWrap( node:getName(), MAX_TEXT_W_AT_SCALE_1 )
		  	  xposition = -width  
		  	end
		  end
		  love.graphics.setFont( fonts[fontSize] )
		  love.graphics.printf( node.getName(), zx+x+xposition, zy+y+5, MAX_TEXT_W_AT_SCALE_1 , ALIGN )
		else
		  local fontSize = math.floor(12 * self.z * (node.size / 8) * bigger)
		  if fontSize < 4 then fontSize = 4 elseif fontSize > 40 then fontSize = 40 end
		  ALIGN = "left"
		  local xposition = 5  
		  -- if node is a leaf, the text direction is opposite to the edge direction (left or right)
		  if node.nConnected == 1 then
			local nx,ny = node.lastConnected:getPosition() 
			local ox,oy = node:getPosition() 
			if (ox - nx) < 0 then 
			  ALIGN = "right"
		  	  local width, wrappedtext = fonts[fontSize]:getWrap( node:getName(), MAX_TEXT_W_AT_SCALE_1 * self.z )
		  	  xposition = -width  
		  	end
		  end
		  love.graphics.setFont( fonts[fontSize] )
		  love.graphics.printf( node.getName(), zx+x+xposition, zy+y+5, MAX_TEXT_W_AT_SCALE_1 * self.z , ALIGN )
		end
            end
	
       local function drawedge( edge )
                local ox, oy = edge.origin:getPosition()
                local tx, ty = edge.target:getPosition()
		ox, oy = ox * self.z + self.offsetX, oy * self.z + self.offsetY
		tx, ty = tx * self.z + self.offsetX, ty * self.z + self.offsetY
		local out1, out2 = false, false
		if ox < 0 or ox > self.w or oy < 0 or oy > self.h then out1 = true end
		if tx < 0 or tx > self.w or ty < 0 or ty > self.h then out2 = true end
		if out1 and out2 then return end
		love.graphics.setColor(unpack(edge.target.color))
		love.graphics.setLineWidth(edge.origin.size/3)
		local c1x, c1y = (ox + tx) / 2 , oy
		local c2x, c2y = (ox + tx) / 2 , ty
		local curve = love.math.newBezierCurve(zx+ox,zy+oy,zx+c1x,zy+c1y,zx+c2x,zy+c2y,zx+tx,zy+ty)
		love.graphics.line( curve:render() )
            end

  graph:draw( drawnode, drawedge )
  love.graphics.setScissor()
  end

function graphScenarioWindow:click(x,y)

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)

  if nodeMove then 
	if love.keyboard.isDown("lctrl") then nodeMove:setAnchor( not nodeMove:isAnchor() ) end
	nodeMove = nil 
  	Window.click(self,x,y)
  	if y > zy then mouseMove = false end
	return
	end

  Window.click(self,x,y)
  if y > zy then mouseMove = false end

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)

  nodeMove = graph:getNodeAt((x-(zx+self.offsetX))/self.z,(y-(zy+self.offsetY))/self.z,1/self.z)

  translation = not nodeMove

  end

function graphScenarioWindow:mousemoved(x,y,dx,dy)
  if translation then
    self.offsetX = self.offsetX + dx
    self.offsetY = self.offsetY + dy
  end
  end

function graphScenarioWindow:mousereleased()
  translation = false
  -- stick/unstick node
  if nodeMove and love.keyboard.isDown("lctrl") then nodeMove:setAnchor( not nodeMove:isAnchor() ) end
  -- center node
  if nodeMove and love.keyboard.isDown("lshift") then 
    self.offsetX, self.offsetY = nodeMove:getPosition()
    self.offsetX, self.offsetY = - self.offsetX + self.w / 2, - self.offsetY + self.h / 2
    self.z = 1.0
  end
  nodeMove = nil
  end

function graphScenarioWindow:update(dt)
  if not layout:getDisplay(self) then return end
  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  local x,y = love.mouse.getPosition()
  if nodeMove then nodeMove:setPosition((x-(zx+self.offsetX))/self.z,(y-(zy+self.offsetY))/self.z) end 
  graph:update( dt )
  end

return graphScenarioWindow

