
local codepage = require 'codepage'		-- windows cp1252 support

dictionnary 		= {}			-- dictionnary indexed by word, with value a couple position (string) 
						-- and level (integer) as in { "((x,y))", lvl } 

-- perform a search in the scenario text on one or several
-- words, and return an iterator on the results (or nil 
-- if no results)
-- each call to the iterator returns 
--   x, y coordinates in the image
--   p the pertinence value of the result
--   i the rank in the result list
--   s the total number of results
-- sorted by descending pertinence
function doSearch( sentence )

	local searchResults = {} -- will be part of the iterator

	-- intermediate iresult is an array indexed with couple {"(((x,y))",level}, 
	-- and value a pertinence integer value p depending on the number of occurences
	-- at this position and level
	local iresult = {} 	
	for word in string.gmatch( sentence , "%a+" ) do
		word = string.lower( word )
    		if dictionnary[word] then
	  		for k,v in pairs(dictionnary[word]) do
				if iresult[ v ] then iresult[ v ] = iresult[ v ] + 1 else iresult[ v ] = 1 end
	  		end
		end
	end

	-- inverse this table
	-- result array is now indexed by pertinence, each entry is an array of {"((x,y))",level} 
	local result = {} 
	for k,v in pairs(iresult) do
  		if result[v] then table.insert( result[v], k ) else result[v] = { k } end 
	end

	-- create flat array of (x,y,pertinence,level) from this
	local sr = {}
	for k,v in pairs(result) do
		for i,j in pairs (v) do 
			local _,_,x,y = string.find( j.p , "(%d+)%s*,%s*(%d+)" )
			table.insert( sr , { x=x , y=y , p=k , l=j.l } ) 
		end
	end

	-- remove x,y duplicates, by calculating a unique pertinence = sum( pertinence / (level+1)) for each,
	for k,v in pairs( sr ) do
		-- check if this position already exists
		local exists = false
		for z,t in pairs( searchResults ) do 
			if t.x == v.x and t.y == v.y then
				t.p = t.p + v.p / ( v.l + 1 )	
				exists = true
				break
			end
		end
		if not exists then
			table.insert( searchResults, { x=v.x, y=v.y, p = v.p / (v.l + 1)} )
		end	
	end

 	-- sort them by decreasing pertinence
	table.sort ( searchResults, function(a,b) return a.p > b.p end )

	-- create and return iterator, or nil if no results
	if not searchResults or table.getn( searchResults ) == 0 then return nil end

	local i = 0
	local iter = function()
	  i = i + 1
	  if i > table.getn( searchResults ) then i = 1 end
	  local u = searchResults[ i ]
	  return u.x, u.y, u.p , i, table.getn( searchResults ) 
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

-- read scenario txt file and build dictionnary
function readScenario( filename )

	local ignore = { "le", "la" , "les", "un" , "une", "des", "ce", "cet", "cette", "ces", "celles", "ca" , "si", "se" , "son", "de" ,
			 "sans", "dans", "pour", "par", "l", "a", "y", "d", "m", "n", "il", "elle", "elles", "ils", "du", "mais", "pour", 
			 "quand", "quoi", "ma", "ta", "ton", "tes", "ni", "ne" , "qui", "que", "qu"
			}

	local reject = function(word) for _,v in ipairs(ignore) do if v == word then return true end end return false end 
 
	-- stack of positions when reading scenario text
	-- each element is a triplet ( level, x , y )
	local stack = {}

	-- insert a default position on the stack (the center of the image)
	table.insert( stack, { level=0, xy="((".. math.floor(layout.W / 2) .. "," .. math.floor(layout.H / 2) .. "))" } )

	local linecount = 0

	if __WINDOWS__ then filename = codepage.utf8tocp1252(filename) end

	for line in io.lines(filename) do

		linecount = linecount + 1

		-- replace accentuated characters
		line = string.stripAccents( line )

		-- determine level of the line
		local i , level = 1 , 0; while string.sub(line,i,i) == '\t' do level = level + 1; i = i + 1 ; end

		-- get level currently in the stack
		local lastelement = stack[ table.getn( stack ) ] 
		local lastlevel = lastelement.level -- we assume there is always at least one element

		-- check if a position is present on the line
		local newposition = string.match(line, "[(][(]%s*%d+%s*,%s*%d+%s*[)][)]" )

		-- compare levels
		if lastlevel == level then

  			-- if new position then replace it in the stack
  			-- this becomes the new position for this level
  			if newposition then
				table.remove( stack ) -- pop
				table.insert( stack, { level=level , xy = newposition } ) -- push
  			else
  			-- otherwise take the existing one
    				newposition = lastelement.xy
  			end
  
		elseif level > lastlevel then
  
			assert(level == lastlevel + 1, "scenario file syntax error: 2 levels are not consecutive at line " .. linecount)
  			if newposition then
    				-- add the new position to the stack
    				-- this becomes the new position at that level
    				table.insert( stack, { level=level, xy=newposition } ) -- push
  			else
    				-- otherwise push the new level with the same position
				table.insert( stack, { level=level, xy=lastelement.xy } )
				newposition = lastelement.xy
  			end
  
		else -- level < lastlevel

  			-- pop the stack until the proper level is reached
  			repeat
        			table.remove( stack )
				lastlevel = stack[ table.getn( stack ) ].level 
  			until level == lastlevel 

  			if newposition then
    				-- if new position, it becomes the new reference at this level
    				table.remove( stack ) -- pop
    				table.insert( stack, { level=level, xy=newposition } ) -- push
  			else
    				-- otherwise take the one from the stack
				newposition = lastelement.xy
  			end

		end

		-- from now on, newposition holds the actual 
		-- position to use on this node

		-- parse all words of the line (ignore all special characters)
		-- insert them in the dictionnary, with a couple { position , level } 
		local pos = { p = newposition, l = level } 
		for word in string.gmatch( line , "%a+" ) do
   			word = string.lower( word )
			if not reject(word) then -- we do not store common words 
   			 if dictionnary[word] then table.insert( dictionnary[word] , pos )
   			 else dictionnary[word] = { pos } end
			end
		end

	end -- end 'for line' ... go next line 

	end

