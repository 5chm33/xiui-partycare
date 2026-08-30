-- XIUI enemy positive-effect watcher regression test.
-- This test runs outside Ashita using a small deterministic buff metadata mock.

package.path = './XIUI/?.lua;./XIUI/?/init.lua;' .. package.path;
package.preload['common'] = function() end;
package.preload['libs.bufftable'] = function()
    return {
        IsBuff = function(effectId)
            return effectId == 40 or effectId == 93; -- Protect / Defense Boost
        end,
        GetBuffIdBySpellId = function(spellId)
            return spellId == 999 and 93 or nil;
        end,
    };
end;

local watcher = require('handlers.enemybuffwatch');

local function assert_equal(actual, expected, label)
    if actual ~= expected then
        error((label or 'assertion failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2);
    end
end

local function assert_truthy(value, label)
    if not value then error(label or 'expected truthy value', 2); end
end

-- A completed magic status-on result targeted at the enemy actor is direct
-- evidence for the visual-only cue. It does not dispatch a command.
watcher.HandleActionPacket({
    UserId = 1001,
    Type = 4,
    Param = 999,
    Targets = {{
        Id = 1001,
        Actions = {{ Message = 230, Param = 93 }},
    }},
});
local active, effectId = watcher.GetRecentPositiveEffect(1001, 300);
assert_truthy(active, 'confirmed positive self effect must activate cue');
assert_equal(effectId, 93, 'cue must retain confirmed positive effect ID');

-- Cast starts, effects on a different target, and known negative statuses must
-- never create a cue. This prevents speculative enemy-buff alerts.
watcher.HandleActionPacket({
    UserId = 1002,
    Type = 8,
    Param = 999,
    Targets = {{ Id = 1002, Actions = {{ Message = 230, Param = 93 }} }},
});
watcher.HandleActionPacket({
    UserId = 1003,
    Type = 4,
    Param = 999,
    Targets = {{ Id = 2003, Actions = {{ Message = 230, Param = 93 }} }},
});
watcher.HandleActionPacket({
    UserId = 1004,
    Type = 4,
    Param = 999,
    Targets = {{ Id = 1004, Actions = {{ Message = 230, Param = 13 }} }},
});
assert_equal(watcher.GetRecentPositiveEffect(1002, 300), false, 'cast start must not activate cue');
assert_equal(watcher.GetRecentPositiveEffect(1003, 300), false, 'other-target effect must not activate cue');
assert_equal(watcher.GetRecentPositiveEffect(1004, 300), false, 'negative effect must not activate cue');

-- A matching effect-loss packet clears the cue immediately.
watcher.HandleMessagePacket({ message = 206, target = 1001, sender = 9999, param = 93 });
assert_equal(watcher.GetRecentPositiveEffect(1001, 300), false, 'effect-loss packet must clear cue');

-- Monster-skill positive status-on outcomes are also accepted only when the
-- effect belongs to the actor itself; zone reset clears all retained evidence.
watcher.HandleActionPacket({
    UserId = 1005,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1005, Actions = {{ Message = 186, Param = 40 }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1005, 300), 'confirmed self skill effect must activate cue');
watcher.HandleZonePacket();
assert_equal(watcher.GetRecentPositiveEffect(1005, 300), false, 'zone reset must clear cue');

print('test_enemybuffwatch.lua: PASS');
