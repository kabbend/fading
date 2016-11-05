require "fading2/dice/vector"
require "fading2/dice/stars"

function newD4star(size)
  if not size then size=1 end
  size=size/1.2
  local new={ {size,size,-size}, {size,-size,size}, {-size,size,size}, {-size,-size,-size} }
  return clone(star,new):set(nil,nil,nil,size*size*size,size*size*size/2)
end

d4={
  faces={{1,2,3},{4,3,2},{3,4,1},{4,2,1}}
}

function newD20star(size)
  if not size then size=1 end
  local new={
        {0.26286500*size, 0.0000000, 0.42532500*size}, 		-- A1
	{-0.26286500*size, 0.0000000, 0.42532500*size}, 	-- B2
        {-0.26286500*size, 0.0000000, -0.42532500*size}, 	-- C3
        {0.26286500*size, 0.0000000, -0.42532500*size}, 	-- D4
        {0.0000000, 0.42532500*size, 0.26286500*size}, 		-- E5
        {0.0000000, 0.42532500*size, -0.26286500*size}, 	-- F6
        {0.0000000, -0.42532500*size, 0.26286500*size}, 	-- G7
        {0.0000000, -0.42532500*size, -0.26286500*size}, 	-- H8
        {0.42532500*size, 0.26286500*size, 0.0000000}, 		-- I9
        {-0.42532500*size, 0.26286500*size, 0.000000}, 		-- J10
        {0.42532500*size, -0.26286500*size, 0.0000000}, 	-- K11
        {-0.42532500*size, -0.26286500*size, 0.0000000} 	-- L12
	} 
  return clone(star,new):set(nil,nil,nil,size*size*size,size*size*size/2)
end

-- ABE, ABG, AGK, AIK, AIE
-- CJF, CJL, CLH, CHD, CDF,
-- LGH, GKH, GLB, BLJ, BJE, 
-- EJF, EIF, IFD, IKD, KDH
d20={
  faces={{1,2,5},{1,2,7},{1,7,11},{1,9,11}, {1,9,5},
  	 {3,10,6},{3,10,12},{3,12,8},{3,8,4}, {3,4,6},
  	 {12,7,8},{7,11,8},{7,12,2},{2,12,10}, {2,10,5},
  	 {5,10,6},{5,9,6},{9,6,4},{9,11,4}, {11,4,8},
	}
}

--[[ D20
	vertices[0] = new VertexPositionColor(new Vector3(-0.26286500f, 0.0000000f, 0.42532500f), Color.Red);
            vertices[1] = new VertexPositionColor(new Vector3(0.26286500f, 0.0000000f, 0.42532500f), Color.Orange);
            vertices[2] = new VertexPositionColor(new Vector3(-0.26286500f, 0.0000000f, -0.42532500f), Color.Yellow);
            vertices[3] = new VertexPositionColor(new Vector3(0.26286500f, 0.0000000f, -0.42532500f), Color.Green);
            vertices[4] = new VertexPositionColor(new Vector3(0.0000000f, 0.42532500f, 0.26286500f), Color.Blue);
            vertices[5] = new VertexPositionColor(new Vector3(0.0000000f, 0.42532500f, -0.26286500f), Color.Indigo);
            vertices[6] = new VertexPositionColor(new Vector3(0.0000000f, -0.42532500f, 0.26286500f), Color.Purple);
            vertices[7] = new VertexPositionColor(new Vector3(0.0000000f, -0.42532500f, -0.26286500f), Color.White);
            vertices[8] = new VertexPositionColor(new Vector3(0.42532500f, 0.26286500f, 0.0000000f), Color.Cyan);
            vertices[9] = new VertexPositionColor(new Vector3(-0.42532500f, 0.26286500f, 0.0000000f), Color.Black);
            vertices[10] = new VertexPositionColor(new Vector3(0.42532500f, -0.26286500f, 0.0000000f), Color.DodgerBlue);
            vertices[11] = new VertexPositionColor(new Vector3(-0.42532500f, -0.26286500f, 0.0000000f), Color.Crimson);
--]]

local function corner(n,xofs,yofs,size,x,y,xa,ya,xb,yb)
  local c,a,b=vector{x,y},vector{xa,ya},vector{xb,yb}
  local o=c-(b-a)/2
  x=b-a
  y=(b+a)/2-c
  
  o=o+0.5*x-size/2*x+yofs*y+xofs*x
  x,y=size*x,size*y
  x,y=o+x,o+y
  local img=love.graphics.getImage("dice/textures/"..n..".png")
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
  faces={{1,2,3,4}, {5,6,7,8}, {1,2,6,5},{2,3,7,6},{3,4,8,7},{4,1,5,8}},
  revertedfaces = {}
}

-- create a reverted table of faces, in which point numbers are index,
-- not value. This will ease face retrieval when knowing the points
for i=1,#d6.faces do
   d6.revertedfaces[i] = {}
    for k,v in ipairs( d6.faces[i]) do
      d6.revertedfaces[i][v] = true
    end
end


function d6.image(n,a,b,c,d,e,f,g,h)
  if n>6 then return end
  local img=love.graphics.getImage("dice/textures/"..n..".png")
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
function d20.image(n,...)
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

-- given 4 points by their index on the star, retrieve the number of
-- the corresponding face
function whichFace(i1,i2,i3,i4)
  for i=1,#d6.faces do
   if d6.revertedfaces[i][i1] and
          d6.revertedfaces[i][i2] and
          d6.revertedfaces[i][i3] and
          d6.revertedfaces[i][i4] then return i end
   end
   return nil
   end




