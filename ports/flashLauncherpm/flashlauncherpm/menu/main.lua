local games = {}
local selected = 1
local scroll = 0
local visible_items = 12
local item_height = 40
local font = nil
local title_font = nil
local launched = false

local colors = {
  bg = {0.11, 0.11, 0.12},
  item = {0.16, 0.16, 0.17},
  item_sel = {0.6, 0.12, 0.15},
  text = {0.78, 0.78, 0.78},
  text_sel = {1, 1, 1},
  title = {0.85, 0.15, 0.18},
  hint = {0.45, 0.45, 0.45},
}

function love.load()
  love.graphics.setBackgroundColor(colors.bg)

  local gamedir = os.getenv("GAMEDIR") or "."
  local programs_path = gamedir .. "/programs"

  font = love.graphics.newFont(16)
  title_font = love.graphics.newFont(22)
  love.graphics.setFont(font)

  -- scan programs directory for .swf files only
  local handle = io.popen('find "' .. programs_path .. '" -maxdepth 2 -name "*.swf" -type f | sort')
  if handle then
    for filepath in handle:lines() do
      local filename = filepath:match("([^/]+)%.swf$")
      if filename and not filename:match("^%.")
         and not filename:match("%.pkg$")
         and not filename:match("%.dat$") then
        table.insert(games, {
          name = filename,
          path = filepath
        })
      end
    end
    handle:close()
  end

  table.sort(games, function(a, b) return a.name:lower() < b.name:lower() end)

  if #games == 0 then
    table.insert(games, {name = "No games found", path = ""})
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  local margin = 20
  local top_y = 60
  local list_h = h - top_y - 40

  visible_items = math.floor(list_h / item_height)

  -- title
  love.graphics.setFont(title_font)
  love.graphics.setColor(colors.title)
  love.graphics.printf("FlashLauncher PM", margin, 14, w, "left")

  -- game count
  love.graphics.setColor(colors.hint)
  love.graphics.printf(selected .. "/" .. #games, 0, 18, w - margin, "right")
  love.graphics.setFont(font)

  -- list
  for i = 1, visible_items do
    local idx = i + scroll
    if idx > #games then break end

    local game = games[idx]
    local y = top_y + (i - 1) * item_height

    -- background
    if idx == selected then
      love.graphics.setColor(colors.item_sel)
    else
      love.graphics.setColor(colors.item)
    end
    love.graphics.rectangle("fill", margin, y, w - margin * 2, item_height - 4, 4)

    -- text
    if idx == selected then
      love.graphics.setColor(colors.text_sel)
    else
      love.graphics.setColor(colors.text)
    end
    love.graphics.printf(game.name, margin + 12, y + 8, w - margin * 2 - 24, "left")
  end

  -- scrollbar
  if #games > visible_items then
    local bar_h = list_h * (visible_items / #games)
    local bar_y = top_y + (scroll / (#games - visible_items)) * (list_h - bar_h)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill", w - 12, bar_y, 4, bar_h, 2)
  end

  -- footer
  love.graphics.setColor(colors.hint)
  local hint = "A: Launch | D-Pad: Navigate | Select in-game to scale"
  love.graphics.printf(hint, 0, h - 28, w, "center")
end

function love.gamepadpressed(joystick, button)
  if button == "dpdown" then
    move_selection(1)
  elseif button == "dpup" then
    move_selection(-1)
  elseif button == "dpright" then
    move_selection(visible_items)
  elseif button == "dpleft" then
    move_selection(-visible_items)
  elseif button == "a" then
    launch_game()
  elseif button == "back" then
    love.event.quit(1)
  end
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit(1)
  elseif key == "p" then
    move_selection(-1)
  elseif key == "l" then
    move_selection(1)
  elseif key == "i" then
    move_selection(-visible_items)
  elseif key == "o" then
    move_selection(visible_items)
  elseif key == "a" or key == "k" then
    launch_game()
  end
end

-- stick navigation with repeat throttle
local stick_timer = 0
local stick_delay = 0.2

function love.update(dt)
  stick_timer = stick_timer + dt
  if stick_timer < stick_delay then return end

  local joysticks = love.joystick.getJoysticks()
  if #joysticks == 0 then return end

  local js = joysticks[1]
  local ly = js:getGamepadAxis("lefty")

  if ly > 0.5 then
    move_selection(1)
    stick_timer = 0
  elseif ly < -0.5 then
    move_selection(-1)
    stick_timer = 0
  end
end

function move_selection(delta)
  selected = selected + delta
  
  -- wrap around at boundaries
  if selected < 1 then 
    selected = #games 
  elseif selected > #games then 
    selected = 1 
  end

  -- keep selection visible
  if selected - scroll > visible_items then
    scroll = selected - visible_items
  elseif selected - scroll < 1 then
    scroll = selected - 1
  end
end

function launch_game()
  if launched then return end
  if not games[selected] or games[selected].path == "" then return end

  launched = true
  -- write selected game path to a file, shell script will read it
  local f = io.open("/tmp/flash_selected_game", "w")
  if f then
    f:write(games[selected].path)
    f:close()
  end
  love.event.quit(0)
end
