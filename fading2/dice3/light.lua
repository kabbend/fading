require "view"
require "vector"

light=vector{0,0,15}

function light.generic(diffuse, specular, transparent, point, normal)
  
  local ray=(point-light)
  local str=ray:abs()
  if str==0 then str=1 end
  local att=math.min(1,10/str)
  ray=ray/str
  
  --transparent objects can have their backfaces lit as well
  --however, specular lighting can only be on the front face
  
  local diff,spec=-math.min(normal..ray,0),0
  if specular and specular>0.0 and diff>0 then
    local reflex=ray+2*diff*normal
    local eye=(point-{view.get()}):norm()
    spec=-math.min(0,eye..reflex)
  end
  if transparent then diff=math.max(0.4,math.abs(math.max(-0.4,-normal..ray))) end
  return math.min(1,1-diffuse-specular + att*(diff*diffuse + spec*specular))
end

function light.cast(point)
  local dir=point-light
  if dir[3]>-0.001 then return end
  return view.project(unpack(light-dir*light[3]/dir[3]))
end

function light.metal(...) return light.generic(0.4,0.5,false,...) end
function light.plastic(...) return light.generic(0.9,0.0,true,...) end


local relax=0
local memory=nil
local drift=vector{0,0,0}
function light.follow(star,dt)

    --where to go?
    local target
    if star then
      target=star.position
      relax=1.5
      memory=star
    elseif relax>0 then
      target=memory.position
      relax=relax-dt
    else
      target=vector{0,0,9}
    end
    
    
    --how fast?
    local diff=target+vector{0,0,6}-light
    if star then
      diff=diff*dt*5
    elseif relax>0 then
      diff=diff*dt*2
    else
      local len=diff:abs()
      if len<1 then len=1 end
      diff=diff*dt*2/len
    end
    light:set(unpack(light+diff))

    --let the bulb dance brownian as well
    local dx,dy,dz=0,0,0
    for i=1,1000*dt do
      dx=dx+math.random()-0.5
      dy=dy+math.random()-0.5
      dz=dz+math.random()-0.5
    end
    drift=(drift+vector{dx,dy,dz}*dt*5)/1.01
    light:set(unpack(light+drift*dt))
    
end
