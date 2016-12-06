
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local widget		= require 'widget'	-- widgets components
local GraphLibrary 	= require('graph').Graph
local SLAXML 		= require 'slaxml'

--
-- graphScenarioWindow class
--
local graphScenarioWindow = Window:new{ class = "graph" , wResizable = true, hResizable = true , movable = true }
local graph = GraphLibrary.new()

function graphScenarioWindow:new( t ) -- create from w, h, x, y
  local new = t or {}
  setmetatable( new , self )
  self.__index = self
  new:loadGraph("s.mm")
  return new
end

function graphScenarioWindow:loadGraph(filename)
  myxml = io.open(filename):read('*all')
  local nodeID = {}
  local id = 1 
  local x,y = 100, 100
  local step = 10 
  local currentID = nil
  local parser = SLAXML:parser{
    startElement = function(name,nsURI,nsPrefix) 
	if name == "node" then 
	  currentID = nodeID[#nodeID] 
	  table.insert(nodeID,id)
	end
        end, -- When "<foo" or <x:foo is seen
    attribute    = function(name,value,nsURI,nsPrefix) 
	if name == "TEXT" then	
	graph:addNode(tostring(id),value,x,y)
	-- create an edge 
	if currentID then graph:connectIDs(tostring(currentID), tostring(id)) end 
	id = id + 1
	x,y = x + step, y + step
	end
	end, -- attribute found on current element
    closeElement = function(name,nsURI)
	if name == "node" then
	  table.remove(nodeID)   
        end -- When "</foo>" or </x:foo> or "/>" is seen
	end,
    text         = function(text)                      end, -- text and CDATA nodes
    comment      = function(content)                   end, -- comments
    pi           = function(target,content)            end, -- processing instructions e.g. "<?yes mon?>"
  }
  parser:parse(myxml,{stripWhitespace=true})

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
                love.graphics.circle( 'fill', zx+x, zy+y, 10 )
		love.graphics.printf( node.getName(), zx+x+5, zy+y+5, 400)
            end,
            function( edge )
                local ox, oy = edge.origin:getPosition()
                local tx, ty = edge.target:getPosition()
                love.graphics.line( zx+ox, zy+oy, zx+tx, zy+ty )
            end)
  love.graphics.setScissor()
  end

local nodeMove = nil 

function graphScenarioWindow:click(x,y)

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)

  if nodeMove then 
	nodeMove:setAnchor(true)
	nodeMove = nil 
  	Window.click(self,x,y)
	return
	end

  Window.click(self,x,y)
  if y > zy then mouseMove = false end

  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  nodeMove = graph:getNodeAt(x-zx,y-zy,10)
  end

function graphScenarioWindow:update(dt)
  local W,H=self.layout.W, self.layout.H
  local zx,zy = -( self.x/self.mag - W / 2), -( self.y/self.mag - H / 2)
  local x,y = love.mouse.getPosition()
  if nodeMove then nodeMove:setPosition(x-zx,y-zy) end 
  graph:update( dt )
  end

return graphScenarioWindow

