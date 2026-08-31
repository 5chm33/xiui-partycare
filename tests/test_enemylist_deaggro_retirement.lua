-- XIUI Enemy List deaggro retirement source-contract regression test.
-- The native Enemy List renderer is UI-heavy, so this validates the explicit
-- claim-update cleanup contract that prevents yellow/deaggroed linked mobs from
-- lingering after the party loses aggro.

local path = 'XIUI/modules/enemylist.lua';
local handle = assert(io.open(path, 'r'));
local source = handle:read('*a');
handle:close();

local function assert_truthy(value, message)
    if not value then error(message or 'assertion failed', 2); end
end

assert_truthy(source:find('enemylist.HandleMobUpdatePacket = function(e)', 1, true) ~= nil,
    'Enemy List must retain a mob-update lifecycle handler');
assert_truthy(source:find('if (e == nil or e.monsterIndex == nil or e.newClaimId == nil) then', 1, true) ~= nil,
    'claim update handler must require authoritative claim-update data');
assert_truthy(source:find('if IsPartyMemberByServerId(e.newClaimId) and GetIsValidMob(e.monsterIndex) then', 1, true) ~= nil,
    'party claim update must retain an active Enemy List card');
assert_truthy(source:find('elseif allClaimedTargets[e.monsterIndex] ~= nil then', 1, true) ~= nil,
    'non-party or unclaimed update must retire an already tracked Enemy List card');
assert_truthy(source:find('allClaimedTargets[e.monsterIndex] = nil;', 1, true) ~= nil,
    'deaggro retirement must remove the card from the claimed-target list');
assert_truthy(source:find('enemyBuffWatch.ClearTarget(serverId);', 1, true) ~= nil,
    'deaggro retirement must clear retained positive-effect cue state');

print('test_enemylist_deaggro_retirement.lua: PASS');
