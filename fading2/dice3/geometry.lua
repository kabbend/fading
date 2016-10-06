require "vector"
require "stars"

function newD4star(size)
  if not size then size=1 end
  size=size/1.2
  local new={ {size,size,-size}, {size,-size,size}, {-size,size,size}, {-size,-size,-size} }
  return clone(star,new):set(nil,nil,nil,size*size*size,size*size*size/2)
end

d4={
  faces={{1,2,3},{4,3,2},{3,4,1},{4,2,1}}
}


local function corner(n,xofs,yofs,size,x,y,xa,ya,xb,yb)
  local c,a,b=vector{x,y},vector{xa,ya},vector{xb,yb}
  local o=c-(b-a)/2
  x=b-a
  y=(b+a)/2-c
  
  o=o+0.5*x-size/2*x+yofs*y+xofs*x
  x,y=size*x,size*y
  x,y=o+x,o+y
  local img=love.graphics.getImage("textures/"..n..".png")
  love.graphics.push()
  love.graphics.transform(o[1],o[2],x[1],x[2],y[1],y[2])
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end

function d4.image(n,x1,y1,x2,y2,x3,y3)
  corner(d4.faces[n][1],0,0.2,0.2,x1,y1,x2,y2,x3,y3)
  corner(d4.faces[n][2],0,0.2,0.2,x2,y2,x3,y3,x1,y1)
  corner(d4.faces[n][3],0,0.2,0.2,x3,y3,x1,y1,x2,y2)
end

function newD6star(size)
  if not size then size=1 end
  size=size/1.6
  local new={ {size,size,size}, {size,-size,size}, {-size,-size,size}, {-size,size,size},
              {size,size,-size}, {size,-size,-size}, {-size,-size,-size}, {-size,size,-size} }
  return clone(star,new):set(nil,nil,nil,size*size*size*2,size*size*size*2)
end
d6= {
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}}
}
function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  local img=love.graphics.getImage("textures/"..n..".png")
  love.graphics.push()
  love.graphics.transform(a,b,c,d,g,h)
  love.graphics.draw(img,0,0,0,1/img:getWidth(),1/img:getHeight())
  love.graphics.pop()
end

function newD8star(size)
  if not size then size=1 end
  local new={ {size,0,0}, {0,-size,0}, {-size,0,0}, {0,size,0},
              {0,0,-size}, {0,0,size} }
  return clone(star,new):set(nil,nil,nil,size*size*size/2,size*size*size/2)
end
d8={
  faces = {
    {5,2,1}, {6,1,2}, {5,3,2}, {6,2,3},
    {5,4,3}, {6,3,4}, {5,1,4}, {6,4,1}
  }
}
function d8.image(n,...)
  corner(n,0,0.4,0.5,...)
end
function round(p,die,star)
  
  local newstar={}
  local newfaces={}
  local edges={}
  
  for i=1,#die.faces do
    local face=die.faces[i]
    local newface={}
    for i=1,#face do
      local ni,pi=math.cycle(i+1,#face),math.cycle(i-1,#face)
      local a,b,c=face[pi],face[i],face[ni]
      local pe,ne=b.."x"..a,b.."x"..c
  
      if not edges[pe] then
        local pt=vector(star[b])+p*(vector(star[a])-star[b])
        table.insert(newstar,pt)
        edges[pe]=#newstar
      end
      
      if not edges[ne] then
        local pt=vector(star[b])+p*(vector(star[c])-star[b])
        table.insert(newstar,pt)
        edges[ne]=#newstar
      end
      table.insert(newface,edges[pe])
      table.insert(newface,edges[ne])
    end
    table.insert(newfaces,newface)
  end
  --az új face-eket is be kell rakni!! majd
  for i=1,#star do
    local newface={}
    for j=1,#star do
      local idx=edges[i.."x"..j]
      if idx then table.insert(newface,idx) end
    end
    --dbg[newface]=newface
    table.insert(newfaces,newface)
  end
  
  for i=1,#newstar do star[i]=newstar[i] end
  die.faces=newfaces
end