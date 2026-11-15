-- Run from the addon folder: luajit tests/core_spec.lua
local realPrint = print

local printed = {}
local inCombat = false
local screenHeight = 1440
local timers = {}
local onEvent
local fake = { scale = 0.65, setScaleCalls = 0 }

print = function(message) table.insert(printed, message) end
UIParent = {
  GetScale = function() return fake.scale end,
  SetScale = function(_, value)
    fake.scale = value
    fake.setScaleCalls = fake.setScaleCalls + 1
  end,
}
InCombatLockdown = function() return inCombat end
GetPhysicalScreenSize = function() return 2560, screenHeight end
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
CreateFrame = function()
  return {
    RegisterEvent = function() end,
    SetScript = function(_, _, handler) onEvent = handler end,
  }
end
SlashCmdList = {}
-- Calling Edit Mode from addon code taints its cached measurements and breaks Blizzard's frames.
local editModeCalls = 0
EditModeMagnetismManager = {
  UpdateTopLevelParentPoints = function() editModeCalls = editModeCalls + 1 end,
}
CANCEL = "Cancel"
StaticPopupDialogs = {}
local shownPopup
StaticPopup_Show = function(name) shownPopup = name end
local reloaded = false
ReloadUI = function() reloaded = true end
-- A StaticPopup runs OnAccept for its first button, and OnCancel with "clicked" for its second button or Escape.
local function closeReloadPopup(accept)
  local dialog = StaticPopupDialogs.SCALETHAS_RELOAD
  if accept then dialog.OnAccept() else dialog.OnCancel(nil, nil, "clicked") end
  shownPopup = nil
  reloaded = false
end

local addon = {}
assert(loadfile("Scale.lua"))("Scalethas", addon)
assert(loadfile("Core.lua"))("Scalethas", addon)
local settingsOpened = 0
addon.OpenSettings = function() settingsOpened = settingsOpened + 1 end

local function fire(event, arg1) onEvent(nil, event, arg1) end
local function nextFrame()
  local due = timers
  timers = {}
  for _, fn in ipairs(due) do fn() end
end
local function slash(text)
  printed = {}
  SlashCmdList.SCALETHAS(text)
end

local passed, failed = 0, 0
local function check(name, actual, expected)
  if actual == expected then
    passed = passed + 1
  else
    failed = failed + 1
    realPrint(string.format("FAIL %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
  end
end
local function checkPrinted(name, fragment)
  for _, line in ipairs(printed) do
    if line:find(fragment, 1, true) then
      passed = passed + 1
      return
    end
  end
  failed = failed + 1
  realPrint(string.format("FAIL %s: no line containing %q in:\n  %s", name, fragment, table.concat(printed, "\n  ")))
end

ScalethasDB = { scale = "big" }
fire("ADDON_LOADED", "Scalethas")
check("corrupt saved scale is dropped", addon.Get(), nil)
ScalethasDB = { scale = 0.1 }
fire("ADDON_LOADED", "Scalethas")
check("out-of-range saved scale is clamped", addon.Get(), 0.3)
fire("ADDON_LOADED", "SomeOtherAddon")
check("other addons loading change nothing", addon.Get(), 0.3)

-- Blizzard's own PLAYER_ENTERING_WORLD handler is what re-measures UIParent for Edit Mode, so the scale must already be in place.
fake.scale = 0.65
ScalethasDB = { scale = 0.5 }
fire("ADDON_LOADED", "Scalethas")
check("saved scale applies as soon as the addon loads", fake.scale, 0.5)

inCombat = true
fake.scale = 0.65
fire("ADDON_LOADED", "Scalethas")
check("loading in combat waits", fake.scale, 0.65)
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check("loading in combat applies after combat", fake.scale, 0.5)

fake.scale = 0.65
fake.setScaleCalls = 0
printed = {}
ScalethasDB = nil
fire("ADDON_LOADED", "Scalethas")
fire("PLAYER_ENTERING_WORLD")
nextFrame()
check("fresh install leaves the scale alone", fake.setScaleCalls, 0)
check("fresh install scale", fake.scale, 0.65)

local seen = "untouched"
addon.OnChange(function(scale) seen = scale end)
slash("0.4")
check("/uiscale 0.4 applies", fake.scale, 0.4)
check("/uiscale 0.4 is saved", ScalethasDB.scale, 0.4)
check("listeners hear about changes", seen, 0.4)
checkPrinted("set message", "Scale set to 0.40.")
check("setting the scale leaves Edit Mode alone", editModeCalls, 0)

slash("  0,5  ")
check("comma decimal with spaces", fake.scale, 0.5)

slash("abc")
check("junk leaves the scale alone", fake.scale, 0.5)
checkPrinted("junk message", "Please enter a number between 0.30 and 1.15.")

slash("0.1")
check("below minimum clamps", fake.scale, 0.3)
checkPrinted("below minimum message", "0.30 is the minimum scale.")

slash("2")
check("above maximum clamps", fake.scale, 1.15)
checkPrinted("above maximum message", "1.15 is the maximum scale.")

check("/uiscale is registered", SLASH_SCALETHAS1, "/uiscale")
check("/scalethas is registered", SLASH_SCALETHAS2, "/scalethas")
check("/st is registered", SLASH_SCALETHAS3, "/st")

slash("")
check("bare command opens the settings", settingsOpened, 1)
check("bare command leaves the scale alone", fake.scale, 1.15)

-- Edit Mode only re-measures in Blizzard's own code, so a live change needs a reload.
shownPopup = nil
slash("0.8")
check("a live change asks for a reload", shownPopup, "SCALETHAS_RELOAD")
check("reload popup text", StaticPopupDialogs.SCALETHAS_RELOAD.text, "Changing scale requires UI reload.")
check("reload popup buttons", StaticPopupDialogs.SCALETHAS_RELOAD.button1 .. "/" .. StaticPopupDialogs.SCALETHAS_RELOAD.button2, "Reload/Cancel")
check("asking doesn't reload yet", reloaded, false)
StaticPopupDialogs.SCALETHAS_RELOAD.OnAccept()
check("Reload reloads the UI", reloaded, true)
check("Reload keeps the new scale", fake.scale, 0.8)
check("Reload keeps the new saved scale", ScalethasDB.scale, 0.8)
reloaded = false
shownPopup = nil

slash("0.8")
check("setting the same scale asks nothing", shownPopup, nil)
slash("abc")
check("junk asks nothing", shownPopup, nil)

slash("0.6")
-- Showing an open popup again cancels it with "override" before re-showing it.
StaticPopupDialogs.SCALETHAS_RELOAD.OnCancel(nil, nil, "override")
check("re-showing the popup keeps the change", fake.scale, 0.6)
slash("0.7")
seen = "untouched"
closeReloadPopup(false)
check("Cancel puts back the scale from before the first change", fake.scale, 0.8)
check("Cancel puts back the saved scale", ScalethasDB.scale, 0.8)
check("Cancel tells listeners", seen, 0.8)
check("Cancel doesn't reload", reloaded, false)

slash("0.6")
closeReloadPopup(false)
slash("0.7")
closeReloadPopup(false)
check("each cancel goes back only to the scale before that popup", fake.scale, 0.8)

slash("2")
closeReloadPopup(true)
-- The engine resets the scale before any handler runs, and no frames (or timers) run during a loading screen.
-- Re-applying at once means Blizzard's own login re-measure for Edit Mode sees our scale.
for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD" }) do
  fake.scale = 0.65
  fire(event)
  check(event .. " re-applies at once", fake.scale, 1.15)
end
check("nothing waits on a timer", #timers, 0)
check("re-applying leaves Edit Mode alone", editModeCalls, 0)
check("re-applying after Blizzard resets asks nothing", shownPopup, nil)

local calls = fake.setScaleCalls
fire("UI_SCALE_CHANGED")
fire("DISPLAY_SIZE_CHANGED")
fire("PLAYER_ENTERING_WORLD")
nextFrame()
check("no SetScale when already at the saved scale", fake.setScaleCalls, calls)

inCombat = true
slash("0.5")
check("combat blocks the change", fake.scale, 1.15)
checkPrinted("combat message", "will apply after combat")
check("a change held for combat asks nothing yet", shownPopup, nil)
printed = {}
fire("UI_SCALE_CHANGED")
nextFrame()
check("combat message is not repeated", #printed, 0)
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check("applies when combat ends", fake.scale, 0.5)
check("a change held for combat asks for the reload once it applies", shownPopup, "SCALETHAS_RELOAD")
closeReloadPopup(false)
check("cancelling a change held for combat puts back the scale", fake.scale, 1.15)

inCombat = true
fake.scale = 0.65
fire("UI_SCALE_CHANGED")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check("re-applying after combat on its own asks nothing", shownPopup, nil)

slash("0.5")
closeReloadPopup(true)

inCombat = true
slash("0.6")
slash("reset")
check("/uiscale reset asks first", shownPopup, "SCALETHAS_RESET")
check("asking changes nothing", ScalethasDB.scale, 0.6)
check("popup text", StaticPopupDialogs.SCALETHAS_RESET.text, "Reset to Blizzard's default UI scaling? This will reload your UI.")
StaticPopupDialogs.SCALETHAS_RESET.OnAccept()
check("reset tells listeners", seen, nil)
check("confirming reloads the UI", reloaded, true)
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check("reset cancels the queued scale", fake.scale, 0.5)
check("reset clears the saved scale", ScalethasDB.scale, nil)

fake.scale = 0.7
fire("UI_SCALE_CHANGED")
nextFrame()
check("inactive after reset", fake.scale, 0.7)

slash("0.4")
closeReloadPopup(false)
check("cancelling from Blizzard's scale puts it back", fake.scale, 0.7)
check("cancelling from Blizzard's scale stays inactive", ScalethasDB.scale, nil)

slash("  ")
check("bare command with spaces opens the settings", settingsOpened, 2)

screenHeight = 1440
slash("PIXEL")
check("pixel-perfect at 1440p", fake.scale, 0.53)
closeReloadPopup(true)
screenHeight = 0
slash("pixel")
check("unknown screen size changes nothing", fake.scale, 0.53)
checkPrinted("unknown screen size message", "UI has not finished loading, please wait a moment and try again.")

print = realPrint
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
