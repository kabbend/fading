local yui_path = (...):match('(.-)[^%.]+$')
local Object = require(yui_path .. 'UI.classic.classic')
local Text = Object:extend('Text')

function Text:new(yui, settings)
    self.yui = yui
    self.x = settings.x or 0 
    self.y = settings.y or 0
    self.center = settings.center 
    self.name = settings.name
    self.text = settings.text or ''
    self.text2 = settings.text2 or nil
    self.text3 = settings.text3 or nil
    self.size = settings.size or 20
    self.bold = settings.bold
    self.semibold = settings.semibold
    self.color = settings.color or {0, 0, 0}

    if self.bold then self.font = love.graphics.newFont(self.yui.Theme.open_sans_bold, math.floor(self.size*0.7))
    elseif self.semibold then self.font = love.graphics.newFont(self.yui.Theme.open_sans_semibold, math.floor(self.size*0.7))
    else self.font = love.graphics.newFont(self.yui.Theme.open_sans_regular, math.floor(self.size*0.7)) end
    
    if self.bold then self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_bold, math.floor(self.size*0.5))
    elseif self.semibold then self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_semibold, math.floor(self.size*0.5))
    else self.font2 = love.graphics.newFont(self.yui.Theme.open_sans_regular, math.floor(self.size*0.5)) end
    
    self.font3 = self.font2
    
    self.w = settings.w or (self.font:getWidth(self.text) + self.size)
    self.h = self.font:getHeight() + math.floor(self.size*0.7)
end

function Text:update(dt)

end

function Text:draw()
    self.yui.Theme.Text.draw(self)
end

return Text
