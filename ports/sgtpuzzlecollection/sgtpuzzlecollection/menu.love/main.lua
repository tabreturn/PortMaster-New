-- main.lua (LÖVE 11.x)

local items = {}
local selected = 1

local ui = {
  padding   = 24,
  fontTitle = nil,
  fontDesc  = nil,
  fontHint  = nil,
  maxImageW = 680,
  maxImageH = 460,
}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function wrapIndex(i, n)
  if n <= 0 then return 1 end
  return ((i - 1) % n) + 1
end

-- -----------------------------------------------------------------------------
-- Load metadata (one-time)
-- -----------------------------------------------------------------------------
local function loadItems()
  items = {}

  if not love.filesystem.getInfo("metadata") then
    love.filesystem.createDirectory("metadata")
  end

  local files = love.filesystem.getDirectoryItems("metadata")
  table.sort(files)

  for _, f in ipairs(files) do
    if f:match("%.lua$") then
      local ok, chunkOrErr = pcall(love.filesystem.load, "metadata/" .. f)
      if ok and chunkOrErr then
        local ok2, def = pcall(chunkOrErr)
        if ok2 and type(def) == "table" then
          def._source = "metadata/" .. f

          -- Auto-load image: same folder + same basename as metadata file
          -- metadata/Foo.lua -> metadata/Foo.png
          do
            local src  = def._source
            local dir  = src:match("^(.-/)") or ""   -- includes trailing "/"
            local base = src:match("([^/]+)%.lua$")

            def._img = nil
            def._imgPath = nil
            def._imgExists = false
            def._imgErr = nil

            if dir ~= "" and base then
              local imgPath = dir .. base .. ".png"
              def._imgPath = imgPath
              def._imgExists = love.filesystem.getInfo(imgPath) ~= nil

              if def._imgExists then
                local okImg, imgOrErr = pcall(love.graphics.newImage, imgPath)
                if okImg then
                  def._img = imgOrErr
                else
                  def._imgErr = tostring(imgOrErr)
                end
              end
            end
          end

          def.title  = def.title  or f:gsub("%.lua$", "")
          def.desc   = def.desc   or ""
          def.script = def.script or ""

          table.insert(items, def)
        end
      end
    end
  end

  if #items == 0 then
    table.insert(items, {
      title  = "No items found",
      desc   = "Create metadata/*.lua files.",
      script = "",
    })
  end

  selected = clamp(selected, 1, #items)
end

-- -----------------------------------------------------------------------------
-- launch_me.sh writer
-- -----------------------------------------------------------------------------
local function osReadFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function osWriteFile(path, data)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function bashQuote(s)
  -- Safe-ish for typical filenames; avoids breaking quotes in bash strings.
  s = tostring(s or "")
  return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", " ")
end

local function runSelected()
  local it = items[selected]
  if not it then return end

  -- Require the metadata fields we need
  local gameJar = it.game_jar
  local gptk    = it.gptk_filename

  if not gameJar or gameJar == "" then return end
  if not gptk or gptk == "" then gptk = "default.gptk" end

  -- Folder LOVE was launched from (OS path)
  local baseDir   = love.filesystem.getSourceBaseDirectory()
  local dstScript = baseDir .. "/launch_me.sh"

  local contents = ([[#!/bin/bash

GAME_JAR="%s"
gptk_filename="%s"

myscript=$(realpath "$0")
mydir=$(dirname "$myscript")
cd "$mydir"
source ./launch.shellscript
exit
]]):format(bashQuote(gameJar), bashQuote(gptk))

  if not osWriteFile(dstScript, contents) then return end
  os.execute(string.format("chmod +x %q", dstScript))

  love.event.quit()
end

-- -----------------------------------------------------------------------------
-- LOVE callbacks
-- -----------------------------------------------------------------------------
function love.load()
  ui.fontTitle = love.graphics.newFont(34)
  ui.fontDesc  = love.graphics.newFont(20)
  ui.fontHint  = love.graphics.newFont(14)

  loadItems()
end

function love.keypressed(key)
  if key == "left" then
    selected = wrapIndex(selected - 1, #items)
  elseif key == "right" then
    selected = wrapIndex(selected + 1, #items)
  elseif key == "return" or key == "kpenter" then
    runSelected()
  elseif key == "escape" then
    love.event.quit()
  end
end

-- -----------------------------------------------------------------------------
-- Drawing
-- -----------------------------------------------------------------------------
local function drawCenteredImage(img, cx, cy, maxW, maxH)
  local iw, ih = img:getWidth(), img:getHeight()
  local s = math.min(maxW / iw, maxH / ih, 1)
  love.graphics.draw(img, cx - (iw*s)/2, cy - (ih*s)/2, 0, s, s)
end

local function drawChevron(x, y, dir, size)
  -- dir = -1 (left) or +1 (right)
  local s = size
  if dir < 0 then
    love.graphics.line(
      x + s, y - s,
      x,     y,
      x + s, y + s
    )
  else
    love.graphics.line(
      x - s, y - s,
      x,     y,
      x - s, y + s
    )
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  love.graphics.clear(0.08, 0.09, 0.10)

  local it = items[selected] or {}

  -- Header
  love.graphics.setFont(ui.fontHint)
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.print(
    "LEFT/RIGHT: browse  |  START/A: launch  |  SELECT: quit",
    ui.padding, ui.padding
  )

  -- Top-right indicator: "N / total"
  do
    local total = #items
    local label = string.format("%d / %d", selected, total)
    local tw = ui.fontHint:getWidth(label)
    love.graphics.print(label, w - ui.padding - tw, ui.padding)
  end

  -- Card region (used for layout math)
  local cardX = ui.padding
  local cardY = ui.padding * 2 + 10
  local cardW = w - ui.padding * 2
  local cardH = h - cardY - ui.padding

  -- Image area
  local cx = cardX + cardW / 2
  local cy = cardY + cardH * 0.35
  local maxW = math.min(ui.maxImageW, cardW - 80)
  local maxH = math.min(ui.maxImageH, cardH * 0.6)

  if it._img then
    love.graphics.setColor(1, 1, 1, 0.95)
    drawCenteredImage(it._img, cx, cy, maxW - 20, maxH - 20)
  else
    -- No image: show on-screen debug
    love.graphics.setFont(ui.fontDesc)
    love.graphics.setColor(1, 1, 1, 0.45)
    love.graphics.printf("No image", cx - maxW/2, cy - 30, maxW, "center")

    love.graphics.setFont(ui.fontHint)
    love.graphics.setColor(1, 1, 1, 0.45)

    local p  = it._imgPath or "(no path computed)"
    local ex = it._imgExists and "yes" or "no"

    love.graphics.printf(("expected: %s"):format(p), cx - maxW/2, cy + 2,  maxW, "center")
    love.graphics.printf(("exists in LOVE fs: %s"):format(ex), cx - maxW/2, cy + 20, maxW, "center")

    if it._imgErr then
      love.graphics.printf(("load error: %s"):format(it._imgErr), cx - maxW/2, cy + 38, maxW, "center")
    end
  end

  -- Left / Right chevrons
  love.graphics.setColor(1, 1, 1, 0.25)
  love.graphics.setLineWidth(4)
  local chevronY = cy
  local chevronSize = 26
  drawChevron(cardX + 32, chevronY, -1, chevronSize)
  drawChevron(cardX + cardW - 32, chevronY, 1, chevronSize)

  -- Text
  local textY = cardY + cardH * 0.65

  love.graphics.setFont(ui.fontTitle)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.printf(it.title or "", cardX + 40, textY, cardW - 80, "center")

  love.graphics.setFont(ui.fontDesc)
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.printf(it.desc or "", cardX + 60, textY + 52, cardW - 120, "center")
end

