local _, addon = ...
local Scale = addon.Scale

local panel = CreateFrame("Frame")
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Scale'thas")

local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

local slider = CreateFrame("Slider", nil, panel, "BackdropTemplate")
slider:SetOrientation("HORIZONTAL")
slider:SetSize(260, 17)
slider:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -24)
slider:SetMinMaxValues(Scale.MIN, Scale.MAX)
slider:SetValueStep(0.01)
slider:SetObeyStepOnDrag(true)
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
slider:SetBackdrop({
  bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
  edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
  tile = true, tileSize = 8, edgeSize = 8,
  insets = { left = 3, right = 3, top = 6, bottom = 6 },
})

local low = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
low:SetText(string.format("%.2f", Scale.MIN))

local high = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
high:SetText(string.format("%.2f", Scale.MAX))

local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
box:SetSize(50, 20)
box:SetPoint("LEFT", slider, "RIGHT", 16, 0)
box:SetAutoFocus(false)
box:SetMaxLetters(6)

local pixel = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
pixel:SetSize(180, 22)
pixel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -32)

local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(160, 22)
reset:SetPoint("LEFT", pixel, "RIGHT", 8, 0)
reset:SetText("Reset to Blizzard")

local function refresh()
  local scale = addon.Get()
  local shown = scale or UIParent:GetScale()
  status:SetText(scale and string.format("Current scale: %.2f", scale) or "Using Blizzard's scale")
  slider:SetValue((Scale.Normalize(shown)))
  box:SetText(string.format("%.2f", shown))
  local perfect = addon.PixelPerfectValue()
  pixel:SetText(perfect and string.format("Pixel-perfect (%.2f)", perfect) or "Pixel-perfect")
end

slider:SetScript("OnValueChanged", function(_, value, userInput)
  if userInput then box:SetText(string.format("%.2f", value)) end
end)

-- Applied on release, not while dragging, because the page itself resizes with the scale.
slider:SetScript("OnMouseUp", function(self)
  local value = Scale.Round(self:GetValue())
  if value ~= addon.Get() then addon.Set(value) end
end)

box:SetScript("OnEnterPressed", function(self)
  local value = Scale.Parse(self:GetText())
  self:ClearFocus()
  if value then
    addon.Set(value)
  else
    refresh()
  end
end)

box:SetScript("OnEscapePressed", function(self)
  self:ClearFocus()
  refresh()
end)

pixel:SetScript("OnClick", function() addon.SetPixelPerfect() end)
reset:SetScript("OnClick", function() addon.ConfirmReset() end)

panel:SetScript("OnShow", refresh)
addon.OnChange(function()
  if panel:IsShown() then refresh() end
end)

panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = refresh

local category = Settings.RegisterCanvasLayoutCategory(panel, "Scale'thas")
Settings.RegisterAddOnCategory(category)

function addon.OpenSettings()
  Settings.OpenToCategory(category:GetID())
end
