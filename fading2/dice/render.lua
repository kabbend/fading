
render={}

--z ordered rendering of elements
function render.zbuffer(z,action)
  table.insert(render,{z,action})
end
function render.paint()
  table.sort(render,function(a,b) return a[1]<b[1] end)
  for i=1,#render do render[i][2]() end
end
function render.clear()
  table.clear(render)
end
draw={}


-- draws a board of 20x20 tiles, on the coordinates -10,-10 to 10 10
-- takes the function for the tile images and the lighting mode
-- returns with the four projected corners of the board 
function render.board(image, light)
  
  --projects the corners of the tiles
  local points={}
  for x=-10,10 do    
    local row={}
    for y=-10,10 do  
      row[y]={diceview.project(x,y,0)}
    end
    points[x]=row
  end

  for x=-10,9 do
    for y=-10,9 do
      local a,b=points[x][y][1],points[x][y][2]
      local c,d=points[x+1][y][1],points[x+1][y][2]
      local e,f=points[x][y+1][1],points[x][y+1][2]
      local l=light(vector{x,y}, vector{0,0,1})
      love.graphics.setColor(255*l,255*l,255*l)
      love.graphics.push()
      love.graphics.transform(a,b,c,d,e,f)
      local image =love.graphics.getImage(image(x,y))
--      love.graphics.draw(image,0,0,0,1/32,1/32)
      love.graphics.pop()
    end
  end
  return {points[-10][-10],points[10][-10], points[10][10],points[-10][10]}
end


--draws the lightbulb
function render.bulb(action)
  local x,y,z,s=diceview.project(unpack(light-{0,0,2}))
  action(z,function()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(255,255,255)
    love.graphics.draw(love.graphics.getImage("default/bulb.png"),x,y,0,s/64,s/64)
    --[[    love.graphics.circle("fill",x,y,s/5,40)
    love.graphics.circle("line",x,y,s/5,40)
    ]]
    love.graphics.setBlendMode("alpha")
  end)
end

--draws a die complete with lighting and projection
function render.die(action, die, star)
  local cam={diceview.get()}
  local projected={}
  for i=1,#star do
    table.insert(projected, {diceview.project(unpack(star[i]+star.position))})
  end

  local front = {}
  local frontd = {}
  local upfront = 10e10 
  local upfrontIndex = 1

  for i=1,#die.faces do
    --prepare face data
    local face=die.faces[i]
    local xy,z,c={},0,vector()
    for i=1,#face do
      c=c+star[face[i]]
      local p = projected[face[i]]
      table.insert(xy,p[1])
      table.insert(xy,p[2])
      z=z+p[3]
    end
    z=z/#face
    c=c/#face
    
    --light it up
    local strength=die.material(c+star.position, c:norm())*1.3
    local color={ die.color[1]*strength, die.color[2]*strength, die.color[3]*strength, die.color[4] }
    local text={die.text[1]*strength,die.text[2]*strength,die.text[3]*strength}
    frontd[i]=c..(1*c+star.position-cam)
    front[i]=frontd[i]<=0

    if frontd[i] < upfront then upfrontIndex = i ; upfront = frontd[i] end
  end

  for i=1,#die.faces do
    --prepare face data
    local face=die.faces[i]
    local xy,z,c={},0,vector()
    for j=1,#face do
      c=c+star[face[j]]
      local p = projected[face[j]]
      table.insert(xy,p[1])
      table.insert(xy,p[2])
      z=z+p[3]
    end
    local strength=die.material(c+star.position, c:norm())*1.3
    local color={ die.color[1]*strength, die.color[2]*strength, die.color[3]*strength, die.color[4] }
    local text={die.text[1]*strength,die.text[2]*strength,die.text[3]*strength}
    z=z/#face
    c=c/#face
    
    --if it is visible then render
    local front = front[i]
    action(z, function()
      if front then 
        if i == upfrontIndex then 
		love.graphics.setColor(255,0,0) else
        	love.graphics.setColor(unpack(color))
	end
        love.graphics.polygon("fill",unpack(xy))
	love.graphics.setColor(unpack(text)) 
        die.image(i,unpack(xy))
      elseif color[4] and color[4]<255 then
        love.graphics.setColor(unpack(text))
        die.image(i,unpack(xy))
        love.graphics.setColor(unpack(color))
        love.graphics.polygon("fill",unpack(xy))
      end
    end) 
  end
end


--draws a shadow of a die
function render.shadow(action,die, star)
  
  local cast={}
  for i=1,#star do
    local x,y=light.cast(star[i]+star.position)
    if not x then return end --no shadow
    table.insert(cast,vector{x,y})
  end
    
  --convex hull, gift wrapping algorithm
  --find the leftmost point
  --thats in the hull for sure
  local hull={cast[1]}
  for i=1,#cast do if cast[i][1]<hull[1][1] then hull[1]=cast[i] end end
  
  --now wrap around the points to find the outermost
  --this algorithm has the additional niceity that it gives us the points clockwise
  --which is important for love.polygon
  repeat
    local point=hull[#hull]
    local endpoint=cast[1]
    if point==endpoint then endpoint=cast[2] end
    
    --see if cast[i] is to the left of our best guess so far
    for i=1,#cast do
      local left = endpoint-point
      left[1],left[2]=left[2],-left[1]
      local diff=cast[i]-endpoint
      if diff..left>0 then
        endpoint=cast[i]
      end
    end
    hull[#hull+1]=endpoint
    if #hull>#cast+1 then return end --we've done something wrong here
  until hull[1]==hull[#hull]
  if #hull<3 then return end --also something wrong or degenerate case
  
  action(0,function()
    love.graphics.setColor(unpack(die.shadow))
    love.graphics.polygon("fill",hull)
  end)
end  

  --draws around a board
  --draw the void with black to remove shadows extending from the board
function render.edgeboard()
  local corners={
    {diceview.project(-10,-10,0)},
    {diceview.project(-10,10,0)},
    {diceview.project(10,10,0)},
    {diceview.project(10,-10,0)}
  }
  love.graphics.setColor(0,0,0)
  
  local m=1 --m is the leftmost corner
  for i=2,4 do if corners[i][1]<corners[m][1] then m=i end end
  
  --n(ext), p(rev), o(ther),m(in) are the four corners
  local n,p,o= corners[math.cycle(m+1,4)], corners[math.cycle(m-1,4)], corners[math.cycle(m+2,4)]
  m=corners[m]
  
  --we ecpect n(ext) to be the clockwise next from m(in)
  if n[2]>p[2] then n,p=p,n end
  
  love.graphics.polygon("fill", -100,m[2], m[1],m[2], n[1],n[2], n[1],-100, -100,-100)
  love.graphics.polygon("fill", n[1],-100, n[1],n[2], o[1],o[2], 100,o[2], 100, -100)
  love.graphics.polygon("fill", 100,o[2], o[1],o[2], p[1],p[2], p[1],100, 100,100)
  love.graphics.polygon("fill", p[1],100, p[1],p[2], m[1],m[2], -100,m[2], -100,100)
  
end

