-- simulation
--  simulates the behaviour of stars in a box
--  stars are set of points rigidly connected together
--  stars bounce when they hit a face of their box
--  stars bounce off each other as if they were spheres
require "dice/vector"

box={ timeleft=0 }
function box:set(x,y,z,gravity,bounce,friction,dt) 
  self.x,self.y,self.z=x or self.x, y or self.y, z or self.z
  self.gravity=gravity or self.gravity
  self.bounce=bounce or self.bounce
  self.friction=friction or self.friction
  self.dt=dt or self.dt
  return self
end

function box:update(dt)
  self.timeleft=self.timeleft+dt
  while(self.timeleft>self.dt) do
    for i=1,#self do
      local s=self[i]
      if s then
      s:push{0,0,-self.gravity*self.dt}
      s:update(self.dt)
      s:box(-self.x,-self.y,0,self.x,self.y,self.z,self.bounce,self.friction)

      -- naive collision
      for j=1,#self do
	if i ~= j then
		if self[j] then
			local v = self[i].position - self[j].position
			if v:abs() < 2 then
      				self[i]:push{unpack(v)}
      				self[j]:push{unpack(-v)}
			end
		end
	end
      end

      if math.abs(s.angular[3])<0.1 then s.angular[3]=0 end
 
      end
    end
    self.timeleft=self.timeleft-self.dt
  end
end

star={position=vector{}, velocity=vector{}, angular=vector{}, mass=0, theta=0}
function star:set(pos,vel,ang,m,th)
  self.position=vector(pos) or self.position
  self.velocity=vector(vel) or self.velocity
  self.angular=vector(ang) or self.angular
  self.mass=m or self.mass
  self.theta=th or self.theta
  return self
end

function star:effect(impulse, displacement)
  return vector(impulse)/self.mass, (displacement or vector{0,0,0})^impulse/self.theta
end

function star:push(impulse, displacement)
  local dv, da=self:effect(impulse, displacement)
  self.velocity=self.velocity+dv
  self.angular=self.angular+da
end

function star:update(dt)
  self.position=self.position+self.velocity*dt
  local r=rotation():set(self.angular:abs()*dt, self.angular:norm())
  for i=1,#self do self[i]=r(self[i]) end
end


--bounce off a wall
function star:wall(index, normal, restitution, friction)
  --frictionless bounce
  local d = self[index]

  local s=normal..(self.angular^d+self.velocity)
  local cv,ca=self:effect(normal,d)
  
  local cs=ca^d+cv --change in contact point speed with unit constraint
  local constraint=(1+restitution)*s/(cs..normal)
  --friction simulation in steps
  local steps=11
  local impulse=-constraint*normal/steps
  local abs=impulse:abs()
  for i=1,steps do
    self:push(impulse,d)
    --here comes the friction
    local s=self.angular^d+self.velocity
    s=(s-(normal..s)*normal)
    self:push(s:norm()*friction*(-abs),d)
  end
end

--bounce inside two parallel infinite walls
function star:parallel(normal, min, max, restitution, friction)
  local lowest, highest = nil,nil
  local lowesta, highesta = min,max
  for i=1,#self do
    local a=(self[i]+self.position)..normal
    if a<=lowesta then
      lowest=i 
      lowesta=a
    end
    if a>=highesta then 
      highest=i 
      highesta=a
    end
  end
  
  if lowest then
    self:wall(lowest,normal,restitution,friction)
    self.position=self.position+normal*(min-lowesta)
  end
  if highest then
    self:wall(highest,-normal,restitution,friction)
    self.position=self.position+normal*(max-highesta)
  end
  
end

--bounce inside a box
function star:box(x1,y1,z1,x2,y2,z2,restitution,friction)
  self:parallel(vector{0,0,1},z1,z2,restitution, friction)
  self:parallel(vector{1,0,0},x1,x2,restitution, friction)
  self:parallel(vector{0,1,0},y1,y2,restitution, friction)
end
