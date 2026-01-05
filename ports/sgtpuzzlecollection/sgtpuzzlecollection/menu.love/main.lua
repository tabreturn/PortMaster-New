-- main.lua (LÖVE 11.x)

local items = {}
local selected = 1

local ui = {
  padding = 24,
  fontTitle = nil,
  fontDesc  = nil,
  fontHint  = nil,
}

local function loadItems()
  items = {}

  if not love.filesystem.getInfo("metadata") then
    love.filesystem.createDirectory("metadata")
  end

  local files = love.filesystem.getDirectoryItems("metadata")
  table.sort(files)

  for _, f in ipairs(files) do
    if f:match("%.lua$") then
      local okLoad, chunk = pcall(love.filesystem.load, "metadata/" .. f)
      if okLoad and chunk then
        local okRun, def = pcall(chunk)
        if okRun and type(def) == "table" then
          def.title = def.title or f:gsub("%.lua$", "")
          def.desc  = def.desc  or ""

          local base = f:match("^(.*)%.lua$")
          local imgPath = base and ("metadata/" .. base .. ".png") or nil
          if imgPath and love.filesystem.getInfo(imgPath) then
            local okImg, img = pcall(love.graphics.newImage, imgPath)
            if okImg then def._img = img end
          end

          items[#items + 1] = def
        end
      end
    end
  end

  if #items == 0 then
    items[1] = { title = "No items found", desc = "Create metadata/*.lua files." }
  end

  if selected < 1 then selected = 1 end
  if selected > #items then selected = #items end
end

local function osWriteFile(path, data)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function bashQuote(s)
  s = tostring(s or "")
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " ")
end

local function runSelected()
  local it = items[selected]
  if not it then return end

  local gameJar = it.game_jar
  if not gameJar or gameJar == "" then return end

  local gptk = it.gptk_filename
  if not gptk or gptk == "" then gptk = "default.gptk" end

  local baseDir = love.filesystem.getSourceBaseDirectory()
  local dst = baseDir .. "/launch_me.sh"

  local contents = ([[#!/bin/bash
GAME_JAR="%s"
gptk_filename="%s"
myscript=$(realpath "$0")
mydir=$(dirname "$myscript")
cd "$mydir"
source ./launch.shellscript
]]):format(bashQuote(gameJar), bashQuote(gptk))

  if not osWriteFile(dst, contents) then return end
  os.execute(string.format("chmod +x %q", dst))
  love.event.quit()
end

function love.load()
  ui.fontTitle = love.graphics.newFont(34)
  ui.fontDesc  = love.graphics.newFont(20)
  ui.fontHint  = love.graphics.newFont(14)
  loadItems()
end

function love.keypressed(key)
  local n = #items
  if key == "left" then
    selected = selected - 1
    if selected < 1 then selected = n end
  elseif key == "right" then
    selected = selected + 1
    if selected > n then selected = 1 end
  elseif key == "return" or key == "kpenter" then
    runSelected()
  elseif key == "escape" then
    love.event.quit()
  end
end

local function drawCenteredImage(img, cx, cy, maxW, maxH)
  local iw, ih = img:getWidth(), img:getHeight()
  local s = math.min(maxW / iw, maxH / ih, 1)
  love.graphics.draw(img, cx - (iw*s)/2, cy - (ih*s)/2, 0, s, s)
end

local function drawChevron(x, y, dir, s)
  if dir < 0 then
    love.graphics.line(x + s, y - s, x, y, x + s, y + s)
  else
    love.graphics.line(x - s, y - s, x, y, x - s, y + s)
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.08, 0.09, 0.10)

  local it = items[selected] or {}

  love.graphics.setFont(ui.fontHint)
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.print("LEFT/RIGHT: browse  |  ENTER: launch  |  ESC: quit", ui.padding, ui.padding)

  local label = string.format("%d / %d", selected, #items)
  love.graphics.print(label, w - ui.padding - ui.fontHint:getWidth(label), ui.padding)

  local cardX = ui.padding
  local cardY = ui.padding * 2 + 10
  local cardW = w - ui.padding * 2
  local cardH = h - cardY - ui.padding

  local cx = cardX + cardW / 2
  local cy = cardY + cardH * 0.35
  local maxW = cardW - 80
  local maxH = cardH * 0.6

  if it._img then
    love.graphics.setColor(1, 1, 1, 0.95)
    drawCenteredImage(it._img, cx, cy, maxW, maxH)
  end

  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.setLineWidth(4)
  drawChevron(cardX + 32,        cy, -1, 26)
  drawChevron(cardX + cardW - 32, cy,  1, 26)

  local textY = cardY + cardH * 0.65

  love.graphics.setFont(ui.fontTitle)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.printf(it.title or "", cardX + 40, textY, cardW - 80, "center")

  love.graphics.setFont(ui.fontDesc)
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.printf(it.desc or "", cardX + 60, textY + 52, cardW - 120, "center")
end
