-- Regression contract: the manual Enemy List Dispel action must retain its
-- stable native Button input while also painting a foreground label after XIUI
-- closes the themed Enemy List window. This prevents a clickable-but-invisible
-- control from returning in future layout changes.

local path = './XIUI/modules/enemylist.lua';
local file, openError = io.open(path, 'r');
if not file then
    error('Unable to open ' .. path .. ': ' .. tostring(openError));
end
local source = file:read('*a');
file:close();

local function require_fragment(fragment, description)
    if not source:find(fragment, 1, true) then
        error('Missing Enemy List Dispel visual contract: ' .. description .. ' (' .. fragment .. ')');
    end
end

require_fragment("imgui.Button('DISPEL##EnemyCareDispel'", 'native clickable Dispel button');
require_fragment('local dispelVisuals = {};', 'per-frame Dispel visual records');
require_fragment('local function DrawDispelVisuals()', 'foreground Dispel painter');
require_fragment('imgui.GetForegroundDrawList()', 'top-layer draw list');
require_fragment("local label = 'DISPEL';", 'visible Dispel label');
require_fragment('DrawDispelVisuals();', 'final foreground paint invocation');

local buttonPos = assert(source:find("imgui.Button('DISPEL##EnemyCareDispel'", 1, true));
local drawPos = assert(source:find('DrawDispelVisuals();', 1, true));
if drawPos <= buttonPos then
    error('Foreground Dispel paint must occur after the native clickable button is created.');
end

print('test_enemylist_dispel_visual.lua: PASS');
