-- XIUI PartyCare native remedy action layout regression test.
-- The renderer is heavily coupled to Ashita/ImGui, so this deterministic source
-- contract protects the essential architecture: the red manual remedy action
-- remains inside the native Party List window and reserves its own card row.

local sourcePath = 'XIUI/modules/partylist/display.lua';
local file, err = io.open(sourcePath, 'rb');
if not file then
    error('Unable to open ' .. sourcePath .. ': ' .. tostring(err));
end
local source = file:read('*all');
file:close();

local function assert_truthy(value, label)
    if not value then error(label or 'expected truthy value', 2); end
end

-- Direct native rendering is intentionally used because the standalone overlay
-- window could lose focus/input or be covered on some Ashita/ImGui builds.
assert_truthy(source:find('Remedy actions are intentionally rendered directly inside the existing Party', 1, true) ~= nil,
    'remedy control must remain in the native Party List window');
assert_truthy(source:find("imgui.Button('REMEDY: ' .. remedyLabel", 1, true) ~= nil,
    'native Party List must draw the visible manual remedy action');
assert_truthy(source:find('partyCare.DispatchRemedy(careState, memIdx)', 1, true) ~= nil,
    'native remedy action must dispatch exactly through the manual remedy helper');
assert_truthy(source:find('imgui.SetCursorScreenPos({hpStartX, entryStartY + entryHeight + 3})', 1, true) ~= nil,
    'native remedy action must be anchored below its party card');
assert_truthy(source:find('bottomSpacing = bottomSpacing + remedyButtonHeight', 1, true) ~= nil,
    'native remedy action must reserve vertical space below its card');
assert_truthy(source:find('local function DrawRemedyVisuals(partyIndex)', 1, true) ~= nil,
    'native remedy action must have a final foreground visual pass');
assert_truthy(source:find('imgui.GetForegroundDrawList()', 1, true) ~= nil,
    'remedy visual must render above themed card backgrounds');
assert_truthy(source:find('DrawRemedyVisuals(partyIndex);', 1, true) ~= nil,
    'foreground remedy visual must be drawn after Party List window completion');
assert_truthy(source:find('PartyCareRemedyActionOverlay##', 1, true) == nil,
    'unreliable separate remedy overlay window must not be reintroduced');
assert_truthy(source:find('DrawRemedyOverlays(', 1, true) == nil,
    'obsolete remedy overlay renderer must remain removed');

print('test_remedy_overlay_layout.lua: PASS');
