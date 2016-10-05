
function love.conf(t)
    t.console = false           -- Attach a console (boolean, Windows only)
    t.title = "dice3d"        -- The title of the window the game is in (string)
    t.author = "way"        -- The author of the game (string)
    t.window.fullscreen = false -- Enable fullscreen (boolean)
    t.window.vsync = false       -- Enable vertical sync (boolean)
    t.window.fsaa = 4           -- The number of FSAA-buffers (number)
    t.window.height = 600       -- The window height (number)
    t.window.width = 800        -- The window width (number)
    --t.version = 0.6             -- The LÖVE version this game was made for (number)
end
