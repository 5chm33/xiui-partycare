-- XIUI PartyCare remedy overlay layout regression test.
-- The renderer is heavily tied to Ashita and ImGui, so this deterministic
-- contract test guards the critical layering architecture: recommendation
-- state is queued during card drawing and the visible manual action is drawn
-- only after the native PartyList window has ended.

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

local function assert_before(first, second, label)
    local firstAt = source:find(first, 1, true);
    local secondAt = source:find(second, 1, true);
    assert_truthy(firstAt ~= nil, 'missing source marker: ' .. first);
    assert_truthy(secondAt ~= nil, 'missing source marker: ' .. second);
    assert_truthy(firstAt < secondAt, label or (first .. ' must precede ' .. second));
end

-- A separate tiny ImGui window must own the actual button. Its flags keep it
-- fixed to the card and visually transparent except for the red action itself.
assert_truthy(source:find('local function DrawRemedyOverlays', 1, true) ~= nil,
    'separate remedy overlay renderer is required');
assert_truthy(source:find('PartyCareRemedyActionOverlay##', 1, true) ~= nil,
    'overlay must have a unique ImGui window identity');
assert_truthy(source:find('ImGuiWindowFlags_NoBackground', 1, true) ~= nil,
    'overlay must leave XIUI card artwork visible');
assert_truthy(source:find("imgui.Button('REMEDY: ' .. overlay.label", 1, true) ~= nil,
    'overlay must contain the visible manual remedy action');

-- DrawMember queues only geometry/state; it must not draw the fragile old
-- inline name-row button, and its reserved space prevents member overlap.
assert_truthy(source:find('remedyOverlays[partyIndex][memIdx] = {', 1, true) ~= nil,
    'party card must queue remedy overlay data');
assert_truthy(source:find('bottomSpacing = bottomSpacing + remedyButtonHeight', 1, true) ~= nil,
    'party card must reserve vertical remedy action space');
assert_truthy(source:find("imgui.SmallButton('Remedy: '", 1, true) == nil,
    'old inline remedy button must not be reintroduced');

-- The overlay must be drawn after the PartyList parent window is ended so no
-- native card/status/window clipping layer can cover the action.
assert_before('imgui.End();\n    imgui.PopStyleVar(2);\n\n    -- Render manual remedy actions after the native party window',
    'DrawRemedyOverlays(partyIndex);',
    'overlay invocation must follow parent PartyList window end');

print('test_remedy_overlay_layout.lua: PASS');
