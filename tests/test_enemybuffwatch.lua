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

-- HorizonXI result-message variants can differ, but a direct positive status
-- icon on a completed enemy self-action remains reliable evidence.
watcher.HandleActionPacket({
    UserId = 1006,
    Type = 11,
    Param = 888,
    Targets = {{ Id = 1006, Actions = {{ Message = 999, Param = 93 }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1006, 300), 'direct positive self effect must not depend on a fixed message ID');

-- Some completed abilities place the gained effect in AdditionalEffect.
watcher.HandleActionPacket({
    UserId = 1007,
    Type = 11,
    Param = 889,
    Targets = {{ Id = 1007, Actions = {{ Message = 999, Param = 0, AdditionalEffect = { Message = 999, Param = 40 } }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1007, 300), 'positive additional effect must activate cue');

-- A completed manual Dispel result clears the matching cue immediately.
watcher.HandleActionPacket({
    UserId = 4001,
    Type = 4,
    Param = 260, -- Dispel
    Targets = {{ Id = 1001, Actions = {{ Message = 341, Param = 93 }} }},
});
assert_equal(watcher.GetRecentPositiveEffect(1001, 300), false, 'successful Dispel result must clear matching cue');

-- A status-off message without an effect icon is still a successful manual
-- Dispel outcome for the card, so no stale cue should remain.
watcher.HandleActionPacket({
    UserId = 1001,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1001, Actions = {{ Message = 230, Param = 40 }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1001, 300), 'second confirmed effect must re-arm cue');
watcher.HandleActionPacket({
    UserId = 4001,
    Type = 4,
    Param = 260, -- Dispel
    Targets = {{ Id = 1001, Actions = {{ Message = 341, Param = 0 }} }},
});
assert_equal(watcher.GetRecentPositiveEffect(1001, 300), false, 'iconless successful Dispel result must clear cue');

-- A status-off result from any other player also clears the recorded effect;
-- the cue belongs to the enemy card, not to the player who dispelled it.
watcher.HandleActionPacket({
    UserId = 1010,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1010, Actions = {{ Message = 230, Param = 40 }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1010, 300), 'third confirmed effect must re-arm cue');
watcher.HandleActionPacket({
    UserId = 4002,
    Type = 11,
    Param = 888,
    Targets = {{ Id = 1010, Actions = {{ Message = 341, Param = 40 }} }},
});
assert_equal(watcher.GetRecentPositiveEffect(1010, 300), false, 'another player removal result must clear cue');

-- Explicit Enemy List retirement clears any cue attached to that mob.
watcher.HandleActionPacket({
    UserId = 1011,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1011, Actions = {{ Message = 230, Param = 40 }} }},
});
watcher.ClearTarget(1011);
assert_equal(watcher.GetRecentPositiveEffect(1011, 300), false, 'retired Enemy List target must clear cue');

-- HorizonXI can place a spell/action value (rather than the removed icon) in
-- another party member's completed Dispel action. Its explicit cast-removal
-- message still authoritatively clears the enemy cue.
watcher.HandleActionPacket({
    UserId = 1012,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1012, Actions = {{ Message = 230, Param = 40 }} }},
});
assert_truthy(watcher.GetRecentPositiveEffect(1012, 300), 'fourth confirmed effect must re-arm cue');
watcher.HandleActionPacket({
    UserId = 4003,
    Type = 4,
    Param = 9999,
    Targets = {{ Id = 1012, Actions = {{ Message = 341, Param = 9999 }} }},
});
assert_equal(watcher.GetRecentPositiveEffect(1012, 300), false, 'iconless teammate cast-removal action must clear cue');

-- The same cast-removal result can be duplicated only as a basic battle
-- message. Its target field still identifies the affected enemy correctly.
watcher.HandleActionPacket({
    UserId = 1013,
    Type = 11,
    Param = 777,
    Targets = {{ Id = 1013, Actions = {{ Message = 230, Param = 40 }} }},
});
watcher.HandleMessagePacket({ message = 342, target = 1013, sender = 4004, param = 0 });
assert_equal(watcher.GetRecentPositiveEffect(1013, 300), false, 'iconless teammate cast-removal message must clear cue');

-- A matching standalone effect-loss packet also clears the cue immediately.
watcher.HandleMessagePacket({ message = 206, target = 1001, sender = 9999, param = 93 });
assert_equal(watcher.GetRecentPositiveEffect(1001, 300), false, 'effect-loss packet must leave cue cleared');

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
