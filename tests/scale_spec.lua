-- Run from the addon folder: luajit tests/scale_spec.lua
local addon = {}
assert(loadfile("Scale.lua"))("Scalethas", addon)
local Scale = addon.Scale

local passed, failed = 0, 0
local function check(name, actual, expected)
  if actual == expected then
    passed = passed + 1
  else
    failed = failed + 1
    print(string.format("FAIL %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
  end
end

check("round down", Scale.Round(0.454), 0.45)
check("round up", Scale.Round(0.456), 0.46)
check("round exact", Scale.Round(0.5), 0.5)

check("clamp below", (Scale.Clamp(0.2)), 0.3)
check("clamp below flag", select(2, Scale.Clamp(0.2)), true)
check("clamp inside", (Scale.Clamp(0.5)), 0.5)
check("clamp inside flag", select(2, Scale.Clamp(0.5)), false)
check("clamp above", (Scale.Clamp(2)), 1.15)
check("clamp above flag", select(2, Scale.Clamp(2)), true)

check("normalize min", (Scale.Normalize(0.30)), 0.3)
check("normalize min flag", select(2, Scale.Normalize(0.30)), false)
check("normalize max", (Scale.Normalize(1.15)), 1.15)
check("normalize max flag", select(2, Scale.Normalize(1.15)), false)
check("normalize rounds into range", (Scale.Normalize(1.154)), 1.15)
check("normalize negative", (Scale.Normalize(-1)), 0.3)

check("parse 0.5", Scale.Parse("0.5"), 0.5)
check("parse .5", Scale.Parse(".5"), 0.5)
check("parse 0,5", Scale.Parse("0,5"), 0.5)
check("parse spaces", Scale.Parse("  0.5  "), 0.5)
check("parse integer", Scale.Parse("1"), 1)
check("parse negative", Scale.Parse("-1"), -1)
check("parse junk", Scale.Parse("abc"), nil)
check("parse empty", Scale.Parse(""), nil)
check("parse two dots", Scale.Parse("0.5.1"), nil)
check("parse exponent", Scale.Parse("1e3"), nil)
check("parse nil", Scale.Parse(nil), nil)

check("pixel 1080", Scale.PixelPerfect(1080), 0.71)
check("pixel 1440", Scale.PixelPerfect(1440), 0.53)
check("pixel 2160", Scale.PixelPerfect(2160), 0.36)
check("pixel 4320 clamps", Scale.PixelPerfect(4320), 0.3)
check("pixel zero", Scale.PixelPerfect(0), nil)
check("pixel nil", Scale.PixelPerfect(nil), nil)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
