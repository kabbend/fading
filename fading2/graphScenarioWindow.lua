
local Window 		= require 'window'	-- Window class & system
local theme		= require 'theme'	-- global theme
local utf8		= require 'utf8'	-- utf8 support 
local widget		= require 'widget'	-- widgets components
local Snapshot		= require 'snapshotClass'-- widgets components
local SLAXML 		= require 'slaxml'	-- XML parser
local GraphLibrary 	= require('graph').Graph
local http 		= require("socket.http")

local graph = GraphLibrary.new()

local translation 	= false		-- are we currently translating within the window ?
local nodeMove 		= nil		-- are we currently moving a node ? If yes, points to the node, nil otherwise 
local fonts 		= {}		-- same font with different sizes

local MAX_TEXT_W_AT_SCALE_1	= 400
local BIGGER_SHARP		= 2
local BIGGER_2_SHARP		= 1.6
local BIGGER_3_SHARP		= 1.3
local ALIGN 			= "left"

-- for scenario search
local textBase                = "Search: "
local text                    = textBase              -- text printed on the screen when typing search keywords
local searchIterator          = nil                   -- iterator on the results, when search is done
local searchPertinence        = 0                     -- will be set by using the iterator, and used during draw
local searchIndex             = 0                     -- will be set by using the iterator, and used during draw
local searchSize              = 0                     -- idem
local currentSearchNode	      = nil

dictionnary 		= {}			-- dictionnary indexed by word

-- perform a search in the scenario text on one or several words, and return an iterator on the results (or nil 
-- if no results). each call to the iterator returns 
--   id node id
--   p the pertinence value of the result
--   i the rank in the result list
--   s the total number of results
-- sorted by descending pertinence
function doSearch( sentence )

	local searchResults = {} -- will be part of the iterator

	-- intermediate iresult is an array indexed with node id,  
	-- and value a pertinence integer value p depending on the number of occurences in the node
	local iresult = {} 	
	for word in string.gmatch( sentence , "%a+" ) do
		word = string.lower( word )
    		if dictionnary[word] then
	  		for k,v in pairs(dictionnary[word]) do
				if iresult[ v ] then iresult[ v ] = iresult[ v ] + 1 else iresult[ v ] = 1 end
	  		end
		end
	end

	-- create flat array of (id,pertinence,level) from this
	for k,v in pairs(iresult) do
		local node = graph:getNode(k)
		table.insert( searchResults , { id=k , p=v , l=node.level } ) 
	end

 	-- sort them by decreasing pertinence, then decreasing level
	table.sort ( searchResults, function(a,b) if a.p == b.p then return a.l > b.l else return a.p > b.p end end )

	-- create and return iterator, or nil if no results
	if not searchResults or table.getn( searchResults ) == 0 then return nil end

	local i = 0
	local iter = function()
	  i = i + 1
	  if i > table.getn( searchResults ) then i = 1 end
	  local u = searchResults[ i ]
	  return u.id, u.p , i, table.getn( searchResults ) 
	  end

	return iter

	end

local tableAccents = {}
    tableAccents["à"] = "a" tableAccents["á"] = "a" tableAccents["â"] = "a" tableAccents["ã"] = "a"
    tableAccents["ä"] = "a" tableAccents["ç"] = "c" tableAccents["è"] = "e" tableAccents["é"] = "e"
    tableAccents["ê"] = "e" tableAccents["ë"] = "e" tableAccents["ì"] = "i" tableAccents["í"] = "i"
    tableAccents["î"] = "i" tableAccents["ï"] = "i" tableAccents["ñ"] = "n" tableAccents["ò"] = "o"
    tableAccents["ó"] = "o" tableAccents["ô"] = "o" tableAccents["õ"] = "o" tableAccents["ö"] = "o"
    tableAccents["ù"] = "u" tableAccents["ú"] = "u" tableAccents["û"] = "u" tableAccents["ü"] = "u"
    tableAccents["ý"] = "y" tableAccents["ÿ"] = "y" tableAccents["À"] = "A" tableAccents["Á"] = "A"
    tableAccents["Â"] = "A" tableAccents["Ã"] = "A" tableAccents["Ä"] = "A" tableAccents["Ç"] = "C"
    tableAccents["È"] = "E" tableAccents["É"] = "E" tableAccents["Ê"] = "E" tableAccents["Ë"] = "E"
    tableAccents["Ì"] = "I" tableAccents["Í"] = "I" tableAccents["Î"] = "I" tableAccents["Ï"] = "I"
    tableAccents["Ñ"] = "N" tableAccents["Ò"] = "O" tableAccents["Ó"] = "O" tableAccents["Ô"] = "O"
    tableAccents["Õ"] = "O" tableAccents["Ö"] = "O" tableAccents["Ù"] = "U" tableAccents["Ú"] = "U"
    tableAccents["Û"] = "U" tableAccents["Ü"] = "U" tableAccents["Ý"] = "Y"
 
-- Strip accents from a string
function string.stripAccents( str )
        
    local normalizedString = ""
 
    for strChar in string.gfind(str, "([%z\1-\127\194-\244][\128-\191]*)") do
        if tableAccents[strChar] ~= nil then
            normalizedString = normalizedString..tableAccents[strChar]
        else
            normalizedString = normalizedString..strChar
        end
    end
        
    return normalizedString
 
    end

local ignore = { "le", "la" , "les", "un" , "une", "des", "ce", "cet", "cette", "ces", "celles", "ca" , "si", "se" , "son", "de" ,
			 "sans", "dans", "pour", "par", "l", "a", "y", "d", "m", "n", "il", "elle", "elles", "ils", "du", "mais", "pour", 
			 "quand", "quoi", "ma", "ta", "ton", "tes", "ni", "ne" , "qui", "que", "qu"
			}

local reject = function(word) for _,v in ipairs(ignore) do if v == word then return true end end return false end 
 
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
  local b, c = http.request( url )
  io.write("downloading " .. url .. " HTTP status = " .. tostring(c) .. ", " .. string.len(tostring(b)) .. " bytes\n")
  if (not b) or (c ~= 200) then return nil end

  -- write it to a file
  local filename = ".localtmpimage"
  local f = io.open(filename,"wb")
  if not f then return nil end
  f:write(b)
  f:close()

  -- store the content of the file in a snapshot with proper size
  return Snapshot:new{ filename = filename , size = size }
  end

function luastrsanitize(str)
	str=str:gsub('\\','\\\\') 
	str=str:gsub('"','&quot;')  
	return str
end


local function writeNode( file, node )
  local text = luastrsanitize(node:getName())
  file:write("<node ID=\"" .. node:getID() .. "\" TEXT=\"" .. text .. "\" >\n")
  if node.level ~= 1 then file:write("<edge COLOR=\"#" .. string.sub(node.color[1],3,4) .. string.sub(node.color[2],3,4) .. string.sub(node.color[3],3,4) .. "\" />\n") end
  for _,c in pairs( node.connected ) do
	if c.level == node.level + 1 then writeNode( file, c ) end
  end
  file:write("</node>\n")
  end

function graphScenarioWindow:saveGraph()

  local savefile = "save.mm"
  if self.filename then savefile = self.filename .. ".save" end
  local xmlfile = io.open(savefile,"w")
  if not xmlfile then return end

  -- start with node 1 (at level 1) and write all nodes with level immediately higher
  local node = graph:getNode("1")
  writeNode( xmlfile, node )
  xmlfile:close()

  layout.notificationWindow:addMessage("Saved scenario file to " .. savefile )

  end

--
-- Load a scenario from a freemind.mm XML file
--
function graphScenarioWindow:loadGraph(filename)

  -- open XML file and read it completely (exit if no file)
  local xmlfile = io.open(filename)
  if not xmlfile then return end
  local myxml = xmlfile:read('*all')
  self.filename = filename

  -- create the parser and appropriate callbacks
  local nodeID = {} 			-- stack to store current id at this level
  local id = 1 				-- incremental ID for the nodes, starting at 1
  local x,y,step = 0, 0, 10
  local currentID = nil			-- current id at this level
  local color = { "0xff", "0x00", "0x00" }
  local givenID = nil

  local parser = SLAXML:parser{

    startElement = function(name,nsURI,nsPrefix) 
	if name == "node" then 
	  currentID = nodeID[#nodeID] 		-- we are about to create a child node. Get the parent id ( = head of stack )
	  givenID = nil				-- we don't know yet if an ID is provided for this node. We assume none
	end
        end, 

    attribute    = function(name,value,nsURI,nsPrefix) 

	if name == "ID" then
	  -- an ID is provided for the node we parse. Store it
	  givenID = value			
	end

	if name == "COLOR" then
	  -- color is a string of the form '#rrggbb' with rr,gg,bb in hexadecimal
	  local r,g,b = string.sub(value,2,3), string.sub(value,4,5), string.sub(value,6,7)	
	  color = { "0x"..r, "0x"..g, "0x"..b }  
	end

	if name == "TEXT" then
	  -- Now we have text, it's time to actually create the node

	  local i = givenID or tostring(id)	-- if we don't have an ID in the XML, take a sequential one
	  table.insert(nodeID,i)		-- insert this ID on top of the stack. It will become the new basis for further creations

	  local a,b = string.find(value, "!%[uploaded image%]")		-- is the text a link to an image, or a real text ?
	  local n
	  if a then
		-- the text is contains an hyperlink for an image (coggle format). Create a node with no text and attach the image 
	        n = graph:addNode(i,"",x,y)
	        local _,_,url,w,h = string.find( string.sub(value,b+2), "(https?://.*[^ ]) (%d+)x(%d+)")
	        n.im = loadimage(url,w)
	  else
		-- create node with text
	    	n = graph:addNode(i,value,x,y)
		-- parse all words of the text (convert it lowercase, and ignore all common words)
		-- insert them in the dictionnary, with the node id 
		local text = string.stripAccents( value ) -- remove all accented characters to ease future search
		for word in string.gmatch( text , "%a+" ) do
   			word = string.lower( word )
			if not reject(word) then -- we do not store common words 
   			 if dictionnary[word] then table.insert( dictionnary[word] , i )
   			 else dictionnary[word] = { i } end
			end
		end
 	  end
	  -- complement the node with some information
	  n.color = color 
	  n.level = #nodeID
	  n.size = math.max(12 - #nodeID , 2)
  	  n:setMass(15/n.level)
	  -- create an edge between this new node and the one currently on top of stack (it's parent)
	  if currentID then graph:connectIDs(tostring(currentID), i) end 

	  if not givenID then id = id + 1 end -- increment the sequential id if used

	  x,y = x + step, y + step -- naive initial positioning

	end
	end, 

    closeElement = function(name,nsURI)

	if name == "node" then
	  -- closing tag for node. We remove it's ID from the top of stack
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
		if (nodeMove == node) or (currentSearchNode == node) then
		  -- the node with current focus is printed bigger
		  local fontSize = math.floor(12 * (node.size / 4) * bigger)
		  if fontSize < 4 then fontSize = 4 elseif fontSize > 40 then fontSize = 40 end
		  ALIGN = "left"
		  local xposition = 5  
		  local width, wrappedtext
		  -- if node is a leaf, the text direction is opposite to the edge direction (left or right)
		  if #node.connected == 1 then
			local nx,ny = node.connected[1]:getPosition() 
			local ox,oy = node:getPosition() 
			if (ox - nx) < 0 then 
			  ALIGN = "right"
		  	  width, wrappedtext = fonts[fontSize]:getWrap( node:getName(), MAX_TEXT_W_AT_SCALE_1 )
		  	  xposition = -width  
		  	end
		  end
		  -- draw a rectangle to highlight search result
		  if currentSearchNode == node then
		    if not wrappedtext then 
			  width, wrappedtext = fonts[fontSize]:getWrap( node:getName(), MAX_TEXT_W_AT_SCALE_1 )
		  	  xposition = -width  
			  end
		    local height = table.getn(wrappedtext)*(fontSize+3)
		    love.graphics.setColor(255,255,255)
		    love.graphics.rectangle("fill",zx+x+xposition, zy+y+5,width,height)	
		    love.graphics.setColor(0,0,0)
		  end
		  love.graphics.setFont( fonts[fontSize] )
		  love.graphics.printf( node.getName(), zx+x+xposition, zy+y+5, MAX_TEXT_W_AT_SCALE_1 , ALIGN )
		else
		  local fontSize = math.floor(12 * self.z * (node.size / 8) * bigger)
		  if fontSize < 4 then fontSize = 4 elseif fontSize > 40 then fontSize = 40 end
		  ALIGN = "left"
		  local xposition = 5  
		  -- if node is a leaf, the text direction is opposite to the edge direction (left or right)
		  if #node.connected == 1 then
			local nx,ny = node.connected[1]:getPosition() 
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

  -- print search zone 
  love.graphics.setColor(0,0,0)
  love.graphics.setFont(theme.fontSearch)
  love.graphics.printf(text, zx + 20, zy + self.h - 20, 400)
  -- print number of the search result is needed
  if searchIterator then love.graphics.printf( "( " .. searchIndex .. " [" .. string.format("%.2f", searchPertinence) .. "] out of " ..
                                                           searchSize .. " )", zx + string.len(text)*8 + 20, zy + self.h - 20, 400) end

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

function graphScenarioWindow:getFocus()
                textActiveCallback = function(t) text = text .. t ; searchIterator = nil; currentSearchNode = nil end
                textActiveBackspaceCallback = function ()
                        if text == textBase then return end
                	searchIterator = nil; currentSearchNode = nil 
                        -- get the byte offset to the last UTF-8 character in the string.
                        local byteoffset = utf8.offset(text, -1)
                        if byteoffset then text = string.sub(text, 1, byteoffset - 1) end
			end
        end

function graphScenarioWindow:looseFocus()
                textActiveCallback = nil
                textActiveBackspaceCallback = nil
        end

function graphScenarioWindow:iterate()
        if searchIterator then 
		local id
		id,searchPertinence,searchIndex,searchSize = searchIterator() 
		currentSearchNode = graph:getNode(id)
    		self.offsetX, self.offsetY = currentSearchNode:getPosition()
    		self.offsetX, self.offsetY = - self.offsetX + self.w / 2, - self.offsetY + self.h / 2
		self.z = 1.0
	end
        end

function graphScenarioWindow:doSearch()
          searchIterator = doSearch( string.gsub( text, textBase, "" , 1) )
          text = textBase
          if searchIterator then 
		local id
		id,searchPertinence,searchIndex,searchSize = searchIterator() 
		currentSearchNode = graph:getNode(id)
    		self.offsetX, self.offsetY = currentSearchNode:getPosition()
    		self.offsetX, self.offsetY = - self.offsetX + self.w / 2, - self.offsetY + self.h / 2
		self.z = 1.0
	  end
          end

return graphScenarioWindow


