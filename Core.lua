local addonName, addon = ...
local Scale = addon.Scale

local PREFIX = "|cfff0c050Scale'thas|r: "

local db
local waitingOnCombat = false
local listeners = {}

local function say(message)
  print(PREFIX .. message)
end

local function fmt(value)
  return string.format("%.2f", value)
end

local function notify()
  for _, listener in ipairs(listeners) do
    listener(db.scale)
  end
end

local function apply()
  if not db.scale then return end
  if InCombatLockdown() then
    if not waitingOnCombat then
      waitingOnCombat = true
      say("will apply after combat")
    end
    return
  end
  waitingOnCombat = false
  -- Skipping no-op calls stops our own SetScale from retriggering the scale events.
  if math.abs(UIParent:GetScale() - db.scale) > 0.001 then
    UIParent:SetScale(db.scale)
    -- Edit Mode only measures UIParent on Blizzard's scale events, which fire before this.
    EditModeMagnetismManager:UpdateTopLevelParentPoints()
  end
end

-- Blizzard resets UIParent's scale in its own handlers for these events; wait a frame to run after them.
local function applySoon()
  C_Timer.After(0, apply)
end

function addon.Get()
  return db.scale
end

function addon.OnChange(listener)
  table.insert(listeners, listener)
end

function addon.Set(value)
  local scale, clamped = Scale.Normalize(value)
  if clamped then
    local limit = scale == Scale.MIN and "minimum" or "maximum"
    say(string.format("%s is the %s scale.", fmt(scale), limit))
  else
    say(string.format("Scale set to %s.", fmt(scale)))
  end
  db.scale = scale
  apply()
  notify()
end

function addon.PixelPerfectValue()
  local _, height = GetPhysicalScreenSize()
  return Scale.PixelPerfect(height)
end

function addon.SetPixelPerfect()
  local scale = addon.PixelPerfectValue()
  if not scale then
    say("UI has not finished loading, please wait a moment and try again.")
    return
  end
  addon.Set(scale)
end

function addon.Reset()
  db.scale = nil
  waitingOnCombat = false
  notify()
end

local RESET_POPUP = "SCALETHAS_RESET"

StaticPopupDialogs[RESET_POPUP] = {
  text = "Reset to Blizzard's default UI scaling? This will reload your UI.",
  button1 = "Reload",
  button2 = CANCEL,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  OnAccept = function()
    addon.Reset()
    ReloadUI()
  end,
}

function addon.ConfirmReset()
  StaticPopup_Show(RESET_POPUP)
end

SLASH_SCALETHAS1 = "/uiscale"
SLASH_SCALETHAS2 = "/scalethas"
SLASH_SCALETHAS3 = "/st"
SlashCmdList.SCALETHAS = function(message)
  local arg = (message or ""):match("^%s*(.-)%s*$"):lower()
  if arg == "" then
    addon.OpenSettings()
  elseif arg == "pixel" then
    addon.SetPixelPerfect()
  elseif arg == "reset" then
    addon.ConfirmReset()
  else
    local value = Scale.Parse(arg)
    if value then
      addon.Set(value)
    else
      say(string.format("Please enter a number between %s and %s.", fmt(Scale.MIN), fmt(Scale.MAX)))
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      ScalethasDB = ScalethasDB or {}
      db = ScalethasDB
      if type(db.scale) == "number" then
        db.scale = (Scale.Normalize(db.scale))
      else
        db.scale = nil
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if waitingOnCombat then apply() end
  else
    applySoon()
  end
end)
