-- Deterministic regression tests for XIUI's optional native PartyCare layer.
-- These tests run outside Ashita with small API mocks and do not dispatch game commands.

package.path = './XIUI/?.lua;./XIUI/?/init.lua;' .. package.path;
package.preload['common'] = function() end;
-- Ashita supplies LuaJIT's bit library at runtime.  Lua 5.4 in this local
-- test environment uses native bitwise operators, so expose the small subset
-- required by the module under test.
_G.bit = {
    band = function(a, b) return a & b; end,
    bor = function(a, b, c, d)
        local value = (a or 0) | (b or 0);
        if c ~= nil then value = value | c; end
        if d ~= nil then value = value | d; end
        return value;
    end,
    lshift = function(a, n) return a << n; end,
    rshift = function(a, n) return a >> n; end,
};

local queuedCommands = {};
local learned = {};
local spellDataReady = true;

local player = {
    GetMainJob = function() return 5; end,
    GetMainJobLevel = function() return 56; end,
    GetSubJob = function() return 3; end,
    GetSubJobLevel = function() return 28; end,
    HasSpellData = function() return spellDataReady; end,
    HasSpell = function(_, id) return learned[id] == true; end,
};

local chat = {
    QueueCommand = function(_, _, command)
        queuedCommands[#queuedCommands + 1] = command;
    end,
};

_G.AshitaCore = {
    GetMemoryManager = function()
        return { GetPlayer = function() return player; end };
    end,
    GetChatManager = function() return chat; end,
};

local care = require('modules.partylist.partycare');

local function deepcopy(value)
    if type(value) ~= 'table' then return value; end
    local result = {};
    for key, child in pairs(value) do result[key] = deepcopy(child); end
    return result;
end

local function base_config()
    return {
        partyCare = {
            enabled = true,
            hoverActionsEnabled = true,
            left = { enabled = true, spell = 'Cure IV' },
            right = { enabled = true, spell = 'Regen' },
            middle = { enabled = true, spell = 'Cure V' },
            mouse4 = { enabled = true, spell = 'Cure III' },
            mouse5 = { enabled = true, spell = 'Cure II' },
            wheelUp = { enabled = true, spell = 'Refresh' },
            wheelDown = { enabled = true, spell = 'Haste' },
            showRemedySuggestions = true,
            showRemedyButtons = true,
            refreshPulseEnabled = true,
            refreshMinMP = 150,
            refreshEarlyEnabled = true,
            refreshDurationSeconds = 150,
            refreshEarlySeconds = 15,
            hastePulseEnabled = true,
            hasteEarlyEnabled = true,
            hasteDurationSeconds = 180,
            hasteEarlySeconds = 15,
            remedies = deepcopy(care._test.default_remedies),
        },
    };
end

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error((label or 'assertion failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2);
    end
end

local function assert_truthy(value, label)
    if not value then error(label or 'expected truthy value', 2); end
end

-- Standard RDM56/WHM28 eligibility: lower /WHM cures are usable; higher-level
-- /WHM spells remain decisively hidden even if the spellbook says they are learned.
learned = { [14] = true, [15] = true, [16] = true, [17] = true, [20] = true, [19] = true, [18] = true, [143] = true, [57] = true, [109] = true };
spellDataReady = true;
care.Reset();
local availability = care.GetSpellAvailability(1);
assert_equal(availability.Poisona, true, 'RDM56/WHM28 can use Poisona');
assert_equal(availability.Paralyna, true, 'RDM56/WHM28 can use Paralyna');
assert_equal(availability.Blindna, true, 'RDM56/WHM28 can use Blindna');
assert_equal(availability.Silena, true, 'RDM56/WHM28 can use Silena');
assert_equal(availability.Cursna, false, 'RDM56/WHM28 must not show Cursna');
assert_equal(availability.Erase, false, 'RDM56/WHM28 must not show Erase');
assert_equal(availability.Viruna, false, 'RDM56/WHM28 must not show Viruna');
assert_equal(availability.Stona, false, 'RDM56/WHM28 must not show Stona');
assert_equal(availability.Haste, true, 'RDM56/WHM28 can use Haste');
assert_equal(availability.Refresh, true, 'RDM56 can use Refresh');

-- A confirmed explicit false must hide a normally level-eligible spell.
learned[17] = false;
care.Reset();
availability = care.GetSpellAvailability(2);
assert_equal(availability.Silena, false, 'confirmed unlearned Silena must be unavailable');

-- While HasSpellData is transiently unavailable, level-eligible remedies remain
-- unknown/manual candidates, but level-locked spells stay hidden.
learned[17] = true;
spellDataReady = false;
care.Reset();
availability = care.GetSpellAvailability(3);
assert_equal(availability.Silena, nil, 'transient spellbook must not suppress level-eligible Silena');
assert_equal(availability.Erase, false, 'transient spellbook must retain Erase level gate');
spellDataReady = true;

-- Direct status decoding has a strict mapping; generic stat-down ids are omitted.
local statuses, known = care._test.get_statuses({ [0] = 3, [1] = 13, [2] = 136, [3] = 255 });
assert_equal(known, true, 'status feed must be recognized');
assert_equal(#statuses, 3, 'status decoder retains raw direct statuses');
assert_equal(care._test.status_to_remedy[136], nil, 'ambiguous stat-down must not receive an Erase mapping');

-- Remedy priority uses only available local spells.  Slow wins when Erase is
-- usable; poison remains when Erase is unavailable.
local settings = base_config().partyCare;
local rules = settings.remedies;
local candidate = care._test.resolve_remedy({13, 3}, settings, { Erase = true, Poisona = true });
assert_equal(candidate.spell, 'Erase', 'Slow/Erase should outrank poison');
candidate = care._test.resolve_remedy({13, 3}, settings, { Erase = false, Poisona = true });
assert_equal(candidate.spell, 'Poisona', 'unavailable Erase must fall through to Poisona');

-- Manual command construction always uses fixed party/alliance tokens and
-- rejects unsupported text.  No target selection command is constructed.
assert_equal(care.BuildManualCommand('Refresh', 0), '/ma "Refresh" <p0>', 'main-party self target');
assert_equal(care.BuildManualCommand('Haste', 6), '/ma "Haste" <a10>', 'alliance party-B target');
assert_equal(care.BuildManualCommand('Cure IV', 17), '/ma "Cure IV" <a25>', 'alliance party-C target');
assert_equal(care.BuildManualCommand('Refresh; /logout', 0), nil, 'unsafe spell text must be rejected');

-- A member with a confirmed-but-empty status feed and enough maximum MP receives
-- the purple missing-Refresh cue.  Positive status icons clear this immediately.
_G.gConfig = base_config();
care.Reset();
local member = { inzone = true, serverid = 101, maxmp = 200, buffs = { [1] = 255 } };
local state = care.GetMemberState(member, 0, 10);
assert_equal(state.alertKind, 'refresh_missing', 'Refresh missing must take priority over Haste');
assert_equal(care.GetNameColor(state, 0xFFFFFFFF, 10), 0xFF8350B8, 'missing Refresh color');
member.buffs = { [1] = 43, [2] = 33, [3] = 255 };
state = care.GetMemberState(member, 0, 11);
assert_equal(state.alertKind, nil, 'active Refresh/Haste icons clear maintenance cues');

-- A locally observed Refresh now survives XIUI cast-bar clearing: begin, finish,
-- and the later expiry use a separate pending-cast record.  This is the path that
-- ensures the purple cue returns after a successfully applied Refresh runs out.
member.buffs = { [1] = 43, [2] = 33, [3] = 255 };
care.Reset();
care.ObserveStartedSpell(900, 109, 101, 100);
assert_truthy(care._test.pending_upkeep_casts()[900], 'Refresh begin must retain a pending cast outside the visual cast bar');
care.ObserveSpellResult(900, false, 102);
assert_equal(care._test.pending_upkeep_casts()[900], nil, 'Refresh finish must clear the pending cast');
state = care.GetMemberState(member, 0, 120);
assert_equal(state.refresh, nil, 'freshly observed Refresh must clear its missing cue');
assert_equal(state.alertKind, nil, 'active Refresh and Haste icons have no maintenance cue before the lead time');
state = care.GetMemberState(member, 0, 240);
assert_equal(state.alertKind, 'refresh_expiring', 'observed Refresh must pulse in its final lead time even while its icon is active');
state = care.GetMemberState(member, 0, 253);
assert_equal(state.alertKind, nil, 'a positive Refresh icon stays clear after the observed duration ends');
member.buffs = { [1] = 255 };
state = care.GetMemberState(member, 0, 254);
assert_equal(state.alertKind, 'refresh_missing', 'once the active Refresh icon disappears after expiry, the purple missing cue returns');
care.Reset();
care.ObserveStartedSpell(900, 109, 101, 100);
care.ObserveSpellResult(900, true, 102);
state = care.GetMemberState(member, 0, 120);
assert_equal(state.alertKind, 'refresh_missing', 'an interrupted Refresh must not suppress the missing cue');

-- With no Refresh cue eligible, Haste appears as the lower-priority yellow cue
-- and follows the same early-pulse behavior while its positive icon is present.
_G.gConfig.partyCare.refreshPulseEnabled = false;
member.buffs = { [1] = 33, [2] = 255 };
care.Reset();
care.ObserveStartedSpell(900, 57, 101, 100);
care.ObserveSpellResult(900, false, 102);
state = care.GetMemberState(member, 0, 267);
assert_equal(state.alertKind, 'haste_expiring', 'observed Haste must pulse in its final lead time while its icon is active');
member.buffs = { [1] = 255 };
state = care.GetMemberState(member, 0, 283);
assert_equal(state.alertKind, 'haste_missing', 'Haste missing is shown when Refresh needs no attention');
assert_equal(care.GetNameColor(state, 0xFFFFFFFF, 283), 0xFFE0B62A, 'missing Haste color');

-- Hover actions queue only when this explicit test invokes a button or wheel
-- handler; inspecting a member state itself must never queue a command.  All
-- mouse buttons are independently configurable manual actions.
assert_equal(#queuedCommands, 0, 'no automatic commands before a user action');
assert_truthy(care.IsMouseButtonBound(0), 'configured left-click binding is detected');
assert_truthy(care.HandleMouseButton(2, 0), 'left click must dispatch configured manual action');
assert_equal(queuedCommands[1], '/ma "Cure IV" <p2>', 'left-click direct command');
assert_truthy(care.HandleMouseButton(2, 1), 'right click must dispatch configured manual action');
assert_equal(queuedCommands[2], '/ma "Regen" <p2>', 'right-click direct command');
assert_truthy(care.HandleMouseButton(2, 2), 'middle click must dispatch configured manual action');
assert_equal(queuedCommands[3], '/ma "Cure V" <p2>', 'middle-click direct command');
assert_truthy(care.HandleMouseButton(2, 3), 'Mouse 4 must dispatch configured manual action');
assert_equal(queuedCommands[4], '/ma "Cure III" <p2>', 'Mouse 4 direct command');
assert_truthy(care.HandleMouseButton(2, 4), 'Mouse 5 must dispatch configured manual action');
assert_equal(queuedCommands[5], '/ma "Cure II" <p2>', 'Mouse 5 direct command');
assert_truthy(care.HandleHoverWheel(state, 2, 1), 'wheel-up must dispatch configured manual action');
assert_equal(queuedCommands[6], '/ma "Refresh" <p2>', 'wheel-up direct command');
assert_truthy(care.HandleHoverWheel(state, 2, -1), 'wheel-down must dispatch configured manual action');
assert_equal(queuedCommands[7], '/ma "Haste" <p2>', 'wheel-down direct command');

print('test_partycare_integration.lua: PASS');
