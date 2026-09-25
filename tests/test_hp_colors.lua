-- Regression coverage for the HP color thresholds.  This module has no Ashita
-- dependency for these pure helpers and is safe to execute outside the game.
local hp = assert(loadfile('XIUI/libs/hp.lua'))()

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error((label or 'assertion failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
    end
end

local lowColor, lowGradient = hp.GetHpColors(0.24)
assert_equal(lowColor, 0xFFFF0000, 'low HP color')
assert_equal(lowGradient[1], '#ec3232', 'low HP gradient start')

local mediumLowColor, mediumLowGradient = hp.GetHpColors(0.25)
assert_equal(mediumLowColor, 0xFFFFA500, 'medium-low HP color')
assert_equal(mediumLowGradient[1], '#ee9c06', 'medium-low HP gradient start')

local mediumHighColor = hp.GetHpColors(0.50)
assert_equal(mediumHighColor, 0xFFFFFF00, 'medium-high HP color')

local highColor = hp.GetHpColors(0.75)
assert_equal(highColor, 0xFFFFFFFF, 'high HP color')

print('test_hp_colors.lua: PASS')
