-- Deterministic regression coverage for XIUI Enemy List manual offensive actions.
-- These tests run outside Ashita and dispatch only into the local mock queue.

package.path = './XIUI/?.lua;./XIUI/?/init.lua;' .. package.path;
package.preload['common'] = function() end;

local queuedCommands = {};
local chat = {
    QueueCommand = function(_, _, command)
        queuedCommands[#queuedCommands + 1] = command;
    end,
};

_G.AshitaCore = {
    GetChatManager = function() return chat; end,
};

local enemyCare = require('modules.enemylistcare');

local function base_config()
    return {
        enemyCare = {
            enabled = true,
            hoverActionsEnabled = true,
            left = { enabled = true, spell = 'Blind' },
            right = { enabled = true, spell = 'Slow' },
            middle = { enabled = true, spell = 'Dia II' },
            mouse4 = { enabled = true, spell = 'Bind' },
            mouse5 = { enabled = true, spell = 'Gravity' },
            wheelUp = { enabled = true, spell = 'Dia' },
            wheelDown = { enabled = true, spell = 'Paralyze' },
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

_G.gConfig = base_config();

-- The visible Dispel control is an explicit manual option, not an inferred
-- enemy-buff detector. It can be shown only on the already selected enemy and
-- must disappear for a different card, a subtarget cursor, or an explicit off.
assert_truthy(enemyCare.CanShowManualDispel(200, 200, false), 'current enemy must show manual Dispel when enabled');
assert_equal(enemyCare.CanShowManualDispel(200, 201, false), false, 'different enemy must not show manual Dispel');
assert_equal(enemyCare.CanShowManualDispel(200, 200, true), false, 'subtarget mode must not show manual Dispel');
_G.gConfig.enemyCare.showDispelButton = false;
assert_equal(enemyCare.CanShowManualDispel(200, 200, false), false, 'explicitly disabled Dispel button must remain hidden');
_G.gConfig.enemyCare.showDispelButton = true;

-- Commands always use the pre-existing <t> and never issue /target. The hovered
-- enemy must be the already selected target, preserving entirely manual targeting.
assert_equal(enemyCare.BuildManualCommand('Dia', 200, 200, false), '/ma "Dia" <t>', 'current enemy command');
assert_equal(enemyCare.BuildManualCommand('Paralyze', 200, 201, false), nil, 'different hovered enemy must not cast');
assert_equal(enemyCare.BuildManualCommand('Paralyze', 200, 200, true), nil, 'subtarget mode must not cast');
assert_equal(enemyCare.BuildManualCommand('Dia; /logout', 200, 200, false), nil, 'unsafe spell text must be rejected');
assert_truthy(enemyCare._test.target_is_current(200, 200, false), 'current enemy must be accepted');
assert_equal(enemyCare._test.target_is_current(200, 201, false), false, 'different enemy must be rejected');
assert_equal(enemyCare._test.target_is_current(200, 200, true), false, 'subtarget state must be rejected');

-- No command is produced until one of the explicit mouse actions is invoked.
assert_equal(#queuedCommands, 0, 'no automatic command before user interaction');
assert_truthy(enemyCare.IsMouseButtonBound(0), 'configured left click is detected');
assert_truthy(enemyCare.HandleMouseButton(200, 200, false, 0), 'left click must dispatch manual offensive spell');
assert_equal(queuedCommands[1], '/ma "Blind" <t>', 'left click command');
assert_truthy(enemyCare.HandleMouseButton(200, 200, false, 1), 'right click must dispatch manual offensive spell');
assert_equal(queuedCommands[2], '/ma "Slow" <t>', 'right click command');
assert_truthy(enemyCare.HandleMouseButton(200, 200, false, 2), 'middle click must dispatch manual offensive spell');
assert_equal(queuedCommands[3], '/ma "Dia II" <t>', 'middle click command');
assert_truthy(enemyCare.HandleMouseButton(200, 200, false, 3), 'Mouse 4 must dispatch manual offensive spell');
assert_equal(queuedCommands[4], '/ma "Bind" <t>', 'Mouse 4 command');
assert_truthy(enemyCare.HandleMouseButton(200, 200, false, 4), 'Mouse 5 must dispatch manual offensive spell');
assert_equal(queuedCommands[5], '/ma "Gravity" <t>', 'Mouse 5 command');
assert_truthy(enemyCare.HandleHoverWheel(200, 200, false, 1), 'wheel up must dispatch manual offensive spell');
assert_equal(queuedCommands[6], '/ma "Dia" <t>', 'wheel up command');
assert_truthy(enemyCare.HandleHoverWheel(200, 200, false, -1), 'wheel down must dispatch manual offensive spell');
assert_equal(queuedCommands[7], '/ma "Paralyze" <t>', 'wheel down command');
assert_truthy(enemyCare.DispatchManualSpell('Dispel', 200, 200, false), 'manual Dispel button action must dispatch on the current target');
assert_equal(queuedCommands[8], '/ma "Dispel" <t>', 'manual Dispel button command');

-- A configured binding never casts merely because the cursor is on a different
-- enemy card or the player is in subtarget selection.
assert_equal(enemyCare.HandleHoverWheel(200, 201, false, 1), false, 'wrong enemy wheel event must not cast');
assert_equal(enemyCare.HandleHoverWheel(200, 200, true, 1), false, 'subtarget wheel event must not cast');
assert_equal(#queuedCommands, 8, 'safety rejections must not queue a command');

-- Fully disabling the feature restores normal XIUI behavior and blocks dispatch.
_G.gConfig.enemyCare.enabled = false;
assert_equal(enemyCare.IsMouseButtonBound(0), false, 'disabled feature must hide mouse binding');
assert_equal(enemyCare.HandleMouseButton(200, 200, false, 0), false, 'disabled feature must not dispatch');
assert_equal(#queuedCommands, 8, 'disabled feature must not queue a command');

print('test_enemylistcare_integration.lua: PASS');
