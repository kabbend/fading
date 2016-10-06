
--[[prototypes]]
  --clone creates a new table that inherits from base, or marks a table as inherited from base
  --clone uses either base.metatable (if present), or new itself as the metatable
  function clone(base,derived)
    if not derived then derived={} end
    if base.metatable then return setmetatable(derived,base.metatable) end
    derived.__index=base
    return setmetatable(derived,derived)
  end
  
  --isa checks if a base object is somewhere in the __index chain of a derived object
  function isa(base,derived)
    if type(derived)~="table" then return false end
    local metatable=getmetatable(derived)
    if not metatable then return false end
    if metatable.__index==base then return true end
    return isa(base,metatable.__index)
  end
  

  --shallow copy, copies keys and values, overwriting existig key-value pairs in new
  function copy(base,new)
    if not new then new={} end
    for k,v in pairs(base) do new[k]=v end
    return new
  end
--[[prototypes]]


--[[prettyprint]]
pretty={}
  function pretty.table(tbl,depth)
    if not depth or depth<1 then return tostring(tbl) end
    
    local gather={}
    for i=1,#tbl do gather[i]=pretty(tbl[i],depth-1) end
    
    for key,value in pairs(tbl) do 
      if type(key)~="number" or key>#tbl then
        gather[#gather+1]=tostring(key)..":"..pretty(value,depth-1)
      end
    end
    return gather
  end

  function pretty.number(nbr)
    if nbr<1001 and nbr>=-1001 and (nbr>0.0001 or nbr<-0.0001) then
      return ("%.3f"):format(nbr)
    else
      return ("%.3e"):format(nbr)
    end
  end

  function pretty.any(value)
    local type=type(value)
    if type=="table" then return "{"..table.concat(pretty.table(value,2),",").."}" end
    return (pretty[type] or tostring)(value)
  end
setmetatable(pretty,{__call=function(p,v) return p.any(v) end})
--[[prettyprint]]

function math.bound(value,min,max) 
  if value<min then return min end
  if value>max then return max end
  return value
end
function math.cycle(value,n)
  while value>n do value=value-n end
  while value<1 do value=value+n end
  return value
end

function table.map(source,func,dest)
  if not dest then dest={} end
  for i=1,#source do dest[i]=func(source[i]) end
  return dest
end
function table.clear(tbl)
  for i=#tbl,1,-1 do tbl[i]=nil end
  return tbl
end