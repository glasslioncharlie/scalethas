local _, addon = ...

local Scale = {}
addon.Scale = Scale

Scale.MIN = 0.30
Scale.MAX = 1.15

-- WoW lays the UI out on a canvas 768 units tall; at 768 / screen height,
-- one UI unit is one screen pixel.
local CANVAS_HEIGHT = 768

function Scale.Round(value)
  return math.floor(value * 100 + 0.5) / 100
end

function Scale.Clamp(value)
  if value < Scale.MIN then return Scale.MIN, true end
  if value > Scale.MAX then return Scale.MAX, true end
  return value, false
end

function Scale.Normalize(value)
  return Scale.Clamp(Scale.Round(value))
end

-- Accepts "0.5", ".5", "0,5" and "-1"; rejects exponents like "1e3".
function Scale.Parse(text)
  if type(text) ~= "string" then return nil end
  local cleaned = text:match("^%s*(.-)%s*$"):gsub(",", ".")
  if cleaned:match("^%-?%d+%.?%d*$") or cleaned:match("^%-?%.%d+$") then
    return tonumber(cleaned)
  end
  return nil
end

function Scale.PixelPerfect(height)
  if type(height) ~= "number" or height <= 0 then return nil end
  return (Scale.Normalize(CANVAS_HEIGHT / height))
end
