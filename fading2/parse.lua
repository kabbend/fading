-- simple help print
function printHelp( basePrgm )

  io.write( basePrgm .. ": " .. basePrgm .. " ")
  for _,op in ipairs(options) do
    local s,e = "", ""
    if not op.mandatory then s="["; e="]"; end 
    local value = ""
    if op.value or op.opcode == "" then value = " " .. op.varname end
    local longopt = ""
    if op.longopcode then longopt = "|"..op.longopcode end
    io.write(s .. op.opcode .. longopt .. value .. e .. " ") 
  end
  io.write("\n")

end

-- simple parser
-- After the parse, the array parse{} will contain
-- * parse.arguments, an array of all values which were not options (eg. a filename, etc.)
-- * parse["varname"], with varname the value defined in options{} below, with corresponding value. If an option
--   does not require a value (eg. --debug), parse["varname"] will contain the boolean true anyway
function doParse( args ) 

local parse = { arguments={} }

local i=2 -- Start at index 2, ie. ignore 1st argument from command line (usually, the name of the directory)

repeat
	local arg = args[i]
	if arg then

	-- help option
	if arg == "--help" then
	    printHelp( args[1] )
	    os.exit()
	end

	local found = false
	local value = nil
	local var = nil
	for _,op in ipairs(options) do
	  

	  -- it's a short option
	  if arg == op.opcode then 
		found = true
		var = op.varname
		if op.value then
		  i = i + 1
		  value = args[i]
		  assert(value,"parse error: a value is required for option " .. op.opcode)
		else
		  value = true
		end

	  elseif op.longopcode and string.sub(arg,1,string.len(op.longopcode)) == op.longopcode then
		found = true
		var = op.varname
		if string.sub(arg,string.len(op.longopcode)+1,string.len(op.longopcode)+1) == "=" then
			-- the value is concatened with the long option 
			if not op.value then error("parse error: no value is needed for option " .. op.longopcode ) end
			value = string.sub(arg,string.len(op.longopcode)+2)		
		else
		    if op.value then -- value required, but at next position
			  i = i + 1
			  value = args[i]
		    else
			  value = true
		    end
		end
	  end
	  
    end
    if found then 
	    parse[ var ] = value 
    else
  	    -- not an option. We store these arguments in an array, in the order they appear
	    parse.arguments[ #parse.arguments + 1 ] = arg
    end
    i = i + 1

    end -- if arg ...

until not arg

-- apply default values if needed, and some checks
local minargs, maxargs = 0,0
for _,op in ipairs(options) do
  if op.opcode ~= "" and op.default and not parse[ op.varname ] then parse[ op.varname ] = op.default end
  if op.opcode ~= "" and op.mandatory and not parse[ op.varname ] then error("argument ".. op.opcode .. " is mandatory and not specified") end
  if op.opcode == "" then 
    if op.mandatory then minargs = minargs + 1; maxargs = maxargs + 1 else maxargs = maxargs + 1 end
  end
end
if #parse.arguments < minargs or #parse.arguments > maxargs then
  if minargs == maxargs then error("incorrect number of arguments. " .. minargs .. " expected. Got " .. #parse.arguments ) 
  else error("incorrect number of arguments. Between .. " .. minargs .. " and " .. maxargs .. " expected. Got " .. #parse.arguments )  end
end

return parse
end
