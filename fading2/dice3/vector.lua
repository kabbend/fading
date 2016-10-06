--[[
  3d vectors and quaternions

  vectors:
    vectors represent vectors or points in R^3, in the 3 dimensional (euclidean) vector space
    vectors are represented as lists, with coordinates at [1], [2], and [3]
    vectors have the usual operators defined on them, listed below
    each operation cretes a new vector from scratch
    vectors are tables, thus they are "reference types", no equality is defined on them
    any entity with [1], [2] and [3] being numbers can be considered a vector
    one can modify the coodinates freely and independently, tehre is no hidden state associated with the vectors
    the vector metatable is used only to enable operator overloading
    
  vector operations:
    *no operations below modify their operands
    __add(a,b): usual addition, returns a new vector
    __sub(a,b): usual subtraction, returns a new vector
    __div(a,s): coordinatewise division by s, returns a new vector
    __unm(a): negate coordinates, returns a new vector
    __pow(a,b): cross product, returns a new vector
    __concat(a,b): dot (inner) product, returns a number
    __tostring(a): a string representation that can be evaluated back to create a new vector, returns a string
    __mul(a,b): scalar product, uses type(x)=="number" to identify the scalar, either a or b can be scalar, returns a new vector or nil
    vector:abs(): length, returns a number
    vector:norm(): returns a unit vector pointing to the same direction as a or vector{0,0,0}
    
--]]
require"base"

vector={metatable={__index={0,0,0}}} --metatable is used because of operator overloading
setmetatable(vector,{__call=clone})

function vector.metatable.__index.set(a,x,y,z)  if not y and not z then x,y,z=x[1],x[2],x[3] end a[1],a[2],a[3]=x,y,z return a end

function vector.metatable.__index.abs(a)        return math.sqrt(a[1]*a[1]+a[2]*a[2]+a[3]*a[3]) end
function vector.metatable.__index.norm(a)       local abs=vector.metatable.__index.abs(a) if abs==0 then abs=1 end return a/abs end

function vector.metatable.__add(a,b)            return vector{a[1]+b[1], a[2]+b[2] ,a[3]+b[3]} end
function vector.metatable.__sub(a,b)            return vector{a[1]-b[1], a[2]-b[2], a[3]-b[3]} end
function vector.metatable.__div(a,s)            return vector{a[1]/s, a[2]/s, a[3]/s} end
function vector.metatable.__unm(a)              return vector{-a[1], -a[2], -a[3]} end
function vector.metatable.__pow(a,b)            return vector{a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3] ,a[1]*b[2]-a[2]*b[1]} end
function vector.metatable.__concat(a,b)         return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
function vector.metatable.__mul(a,b)    
  if type(b)=="number" then return vector{a[1]*b, a[2]*b, a[3]*b} 
  elseif type(a)=="number" then return vector{a*b[1], a*b[2], a*b[3]} end 
end


--[[
  rotation:
    rotations in 3d space are stored as quaterions
    represented in lists, with [1],[2],[3],[4] meaning the scalar and vectorial parts of the quaternion, respectively
    there is hidden state (precalculated data) stored in indices 5-13. to update them after directly modifying 1-4, call rotation.precalculate
    designed to work either with vectors or with 3 separate coordinates
    
  rotation operations
  
    rotation.precalculate(r): tags a list as a rotation and precalculates data for faster application, modifies r, returns r
    *no operations below modify their operands
    rotation:set(a,x,y,z):  if x is a list then returns a new rotation around vector x by angle a(in radians), 
                            else returns a new rotation around x,y,z by angle a(in radians)
    __pow(a,b): combine two rotations into one, returns a new rotation
    __unm(a): inverse rotation, returns a new rotation
    __call(x,y,z): if x is a list, returns a new rotated vector of x, else returns three coordinates of the rotated x,y,z
--]]


rotation={metatable={__index={1,0,0,0,0,0,0,0,0,0,0,0,0}}} --metatable is used because of operator overloading
setmetatable(rotation, {__call=clone})

function rotation.metatable.__index.set(r,a,x,y,z)
  if not y and not z then x,y,z=x[1],x[2],x[3] end
  local sin=math.sin(a/2)
  local abs=math.sqrt(x*x+y*y+z*z)
  if abs==0 then abs=1 end
  r[1],r[2],r[3],r[4]=math.cos(a/2), x*sin/abs,y*sin/abs,z*sin/abs
  return rotation.precalculate(r)
end

function rotation.precalculate(r) 
  r[ 5]= r[1]*r[2]
  r[ 6]= r[1]*r[3]
  r[ 7]= r[1]*r[4]
  r[ 8]=-r[2]*r[2]
  r[ 9]= r[2]*r[3]
  r[10]= r[2]*r[4]
  r[11]=-r[3]*r[3]
  r[12]= r[3]*r[4]
  r[13]=-r[4]*r[4]
  return rotation(r)
end

function rotation.metatable.__pow(a,b) 
  return rotation.precalculate{a[1]*b[1]-a[2]*b[2]-a[3]*b[3]-a[4]*b[4],
          a[1]*b[2]+a[2]*b[1]+a[3]*b[4]-a[4]*b[3],
          a[1]*b[3]+a[3]*b[1]+a[4]*b[2]-a[2]*b[4],
          a[1]*b[4]+a[4]*b[1]+a[2]*b[3]-a[3]*b[2]}
end
function rotation.metatable.__unm(r) return rotation.precalculate{r[1], -r[2], -r[3], -r[4]} end

function rotation.metatable.__call(r,x,y,z) 
  if not y and not z then
    return vector{x[1]+2*((r[11]+r[13])*x[1]+(r[9]-r[7])*x[2]+(r[6]+r[10])*x[3]),
              x[2]+2*((r[7]+r[9])*x[1]+(r[8]+r[13])*x[2]+(r[12]-r[5])*x[3]),
              x[3]+2*((r[10]-r[6])*x[1]+(r[5]+r[12])*x[2]+(r[8]+r[11])*x[3])}
  else
    return x+2*((r[11]+r[13])*x+(r[9]-r[7])*y+(r[6]+r[10])*z),
            y+2*((r[7]+r[9])*x+(r[8]+r[13])*y+(r[12]-r[5])*z),
            z+2*((r[10]-r[6])*x+(r[5]+r[12])*y+(r[8]+r[11])*z)
  end
end

--end of file