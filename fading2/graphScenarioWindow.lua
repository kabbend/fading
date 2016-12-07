
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	-- widgets components
local SLAXML 		= require 'slaxml'	-- XML parser
local GraphLibrary 	= require('graph').Graph

local graph = GraphLibrary.new()

local translation = nil		-- are we currently translating within the window ?

--
-- graphScenarioWindow class
--
local graphScenarioWindow = Window:new{ class = "graph" , wResizable = true, hResizable = true , movable = true }

function graphScenarioWindow:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new.offsetX, new.offsetY = 0, 0	-- this offset is applied each time we manipulate nodes, it represents the translation
					-- we do with the mouse within the window
  new:loadGraph("s.mm")			-- FIXME hardcoded
  new.z = 1.0
  return new
end

function graphScenarioWindow:zoom(v)
  if v < 0 or self.z < 1.0 then v = v / 10 end
  self.z = self.z + v
  if self.z <= 0 then self.z = 0.1 end
  if self.z >= 10 then self.z = 10 end 
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
  local x,y,step = 10, 10, 10
  local currentID = nil			-- current id at this level
  local color = { 0, 0, 0 }

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
	  local n = graph:addNode(tostring(id),value,x,y)
  	  n:setMass(string.len(value)/30)
	  n.color = color 
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

  self:drawBack()
  self:drawBar()
  self:drawResize()
  
  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)

  love.graphics.setScissor(zx,zy,self.w,self.h)
  graph:draw( function( node )
                local x, y = node:getPosition()
		x, y = x * self.z, y * self.z
		love.graphics.setColor(unpack(node.color))
                love.graphics.circle( 'fill', zx+x+self.offsetX, zy+y+self.offsetY, 10 )
		love.graphics.printf( node.getName(), zx+x+5+self.offsetX, zy+y+5+self.offsetY, 400)
            end,
            function( edge )
                local ox, oy = edge.origin:getPosition()
                local tx, ty = edge.target:getPosition()
		ox, oy = ox * self.z, oy * self.z
		tx, ty = tx * self.z, ty * self.z
		love.graphics.setColor(unpack(edge.origin.color))
                love.graphics.line( zx+ox+self.offsetX, zy+oy+self.offsetY, zx+tx+self.offsetX, zy+ty+self.offsetY )
            end)
  love.graphics.setScissor()
  end

local nodeMove = nil 

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

  nodeMove = graph:getNodeAt((x-(zx+self.offsetX))/self.z,(y-(zy+self.offsetY))/self.z,10)

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
  end

function graphScenarioWindow:update(dt)
  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  local x,y = love.mouse.getPosition()
  if nodeMove then nodeMove:setPosition((x-(zx+self.offsetX))/self.z,(y-(zy+self.offsetY))/self.z) end 
  graph:update( dt )
  end

return graphScenarioWindow

