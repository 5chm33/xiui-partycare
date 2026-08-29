--[[
    XIUI PartyCare Feature Module

    Optional, manual party-care extensions for XIUI's native party list.
    This module never casts automatically and never changes the player's target.
    A spell command can be queued only by an explicit mouse click or mouse-wheel
    action over an in-zone party entry.
]]

require('common');

local partyCare = {};
local unpack_args = table.unpack or unpack;

local JOB_WHITEMAGE = 3;
local JOB_REDMAGE = 5;
local JOB_SCHOLAR = 20;

local REFRESH_STATUS_ID = 43;
local HASTE_STATUS_ID = 33;

-- These standard spells have stable resource ids and audited effective level
-- requirements.  The local spellbook remains authoritative whenever it is ready.
local STANDARD_SPELLS = {
    ['Poisona'] = { id = 14, levels = {[JOB_WHITEMAGE] = 6, [JOB_SCHOLAR] = 10} },
    ['Paralyna'] = { id = 15, levels = {[JOB_WHITEMAGE] = 9, [JOB_SCHOLAR] = 12} },
    ['Blindna'] = { id = 16, levels = {[JOB_WHITEMAGE] = 14, [JOB_SCHOLAR] = 17} },
    ['Silena'] = { id = 17, levels = {[JOB_WHITEMAGE] = 19, [JOB_SCHOLAR] = 22} },
    ['Stona'] = { id = 18, levels = {[JOB_WHITEMAGE] = 39, [JOB_SCHOLAR] = 50} },
    ['Viruna'] = { id = 19, levels = {[JOB_WHITEMAGE] = 34, [JOB_SCHOLAR] = 46} },
    ['Cursna'] = { id = 20, levels = {[JOB_WHITEMAGE] = 29, [JOB_SCHOLAR] = 32} },
    ['Erase'] = { id = 143, levels = {[JOB_WHITEMAGE] = 32, [JOB_SCHOLAR] = 39} },
    ['Dispel'] = { id = 260, levels = {[JOB_REDMAGE] = 32, [JOB_SCHOLAR] = 32} },
    ['Haste'] = { id = 57, levels = {[JOB_WHITEMAGE] = 40, [JOB_REDMAGE] = 48} },
    ['Refresh'] = { id = 109, levels = {[JOB_REDMAGE] = 41} },
};

-- Direct mappings only.  Broad HorizonXI "stat down" icon groups are excluded:
-- they can represent transitional or ambiguous state and cannot be safely
-- translated into a single Erase recommendation.
local STATUS_TO_REMEDY = {
    [3] = 'poison', [4] = 'paralyze', [5] = 'blind', [6] = 'silence',
    [7] = 'petrify', [8] = 'disease', [9] = 'curse', [10] = 'stun',
    [11] = 'bind', [12] = 'gravity', [13] = 'slow', [15] = 'doom',
    [21] = 'addle', [31] = 'plague',
    [128] = 'elemental_dot', [129] = 'elemental_dot', [130] = 'elemental_dot',
    [131] = 'elemental_dot', [132] = 'elemental_dot', [133] = 'elemental_dot',
    [134] = 'dia', [135] = 'bio', [156] = 'flash', [186] = 'helix',
    [192] = 'requiem', [194] = 'elegy',
};

local DEFAULT_REMEDIES = {
    paralyze = { spell = 'Paralyna', enabled = true, priority = 100 },
    doom = { spell = 'Cursna', enabled = true, priority = 97 },
    petrify = { spell = 'Stona', enabled = true, priority = 96 },
    curse = { spell = 'Cursna', enabled = true, priority = 95 },
    plague = { spell = 'Viruna', enabled = true, priority = 94 },
    disease = { spell = 'Viruna', enabled = true, priority = 93 },
    gravity = { spell = 'Erase', enabled = true, priority = 90 },
    bind = { spell = 'Erase', enabled = true, priority = 89 },
    slow = { spell = 'Erase', enabled = true, priority = 85 },
    silence = { spell = 'Silena', enabled = true, priority = 70 },
    blind = { spell = 'Blindna', enabled = true, priority = 60 },
    poison = { spell = 'Poisona', enabled = true, priority = 50 },
    bio = { spell = 'Erase', enabled = true, priority = 45 },
    dia = { spell = 'Erase', enabled = true, priority = 45 },
    addle = { spell = 'Erase', enabled = true, priority = 44 },
    flash = { spell = 'Erase', enabled = true, priority = 43 },
    stun = { spell = 'Erase', enabled = true, priority = 42 },
    elegy = { spell = 'Erase', enabled = true, priority = 40 },
    requiem = { spell = 'Erase', enabled = true, priority = 39 },
    helix = { spell = 'Erase', enabled = true, priority = 38 },
    elemental_dot = { spell = 'Erase', enabled = true, priority = 10 },
};

local DEFAULT_SETTINGS = {
    enabled = false,
    hoverActionsEnabled = false,
    left = { enabled = false, spell = 'Cure IV' },
    right = { enabled = false, spell = 'Regen' },
    middle = { enabled = false, spell = 'Cure V' },
    mouse4 = { enabled = false, spell = 'Cure III' },
    mouse5 = { enabled = false, spell = 'Cure V' },
    wheelUp = { enabled = true, spell = 'Refresh' },
    wheelDown = { enabled = true, spell = 'Haste' },
    showRemedySuggestions = true,
    showRemedyButtons = true,
    refreshPulseEnabled = false,
    refreshMinMP = 150,
    refreshEarlyEnabled = true,
    refreshDurationSeconds = 150,
    refreshEarlySeconds = 15,
    hastePulseEnabled = false,
    hasteEarlyEnabled = true,
    hasteDurationSeconds = 180,
    hasteEarlySeconds = 15,
    remedies = DEFAULT_REMEDIES,
};

local observedUpkeep = {};
local pendingUpkeepCasts = {};
local availabilityCache = { at = 0, values = {} };

local function safe_call(object, method, ...)
    if object == nil then return nil; end
    local args = {...};
    local count = select('#', ...);
    local ok, result = pcall(function()
        local fn = object[method];
        if type(fn) ~= 'function' then return nil; end
        return fn(object, unpack_args(args, 1, count));
    end);
    if ok then return result; end
    return nil;
end

local function bool_or_nil(value)
    if type(value) == 'boolean' then return value; end
    if type(value) == 'number' then return value ~= 0; end
    return nil;
end

local function local_jobs()
    if AshitaCore == nil or type(AshitaCore.GetMemoryManager) ~= 'function' then return nil; end
    local memory = AshitaCore:GetMemoryManager();
    local player = safe_call(memory, 'GetPlayer');
    if player == nil then return nil; end

    local mainJob = tonumber(safe_call(player, 'GetMainJob'));
    local mainLevel = tonumber(safe_call(player, 'GetMainJobLevel'));
    local subJob = tonumber(safe_call(player, 'GetSubJob'));
    local subLevel = tonumber(safe_call(player, 'GetSubJobLevel')) or 0;

    if mainJob == nil or mainLevel == nil then return nil; end
    return {
        player = player,
        mainJob = mainJob,
        mainLevel = mainLevel,
        subJob = subJob,
        subLevel = subLevel,
    };
end

local function usable_for_jobs(spellInfo, jobs)
    if spellInfo == nil or jobs == nil then return nil; end
    local mainRequired = spellInfo.levels[jobs.mainJob];
    local subRequired = spellInfo.levels[jobs.subJob];
    if mainRequired ~= nil and jobs.mainLevel >= mainRequired then return true; end
    if subRequired ~= nil and jobs.subLevel >= subRequired then return true; end
    if mainRequired ~= nil or subRequired ~= nil then return false; end
    return false;
end

-- Produces false only for a definitive failure: a confirmed unlearned spell or
-- a standard spell that the local effective main/subjob levels cannot cast.
-- Nil means spellbook data is transiently unavailable, so a level-usable manual
-- candidate stays visible instead of silently disappearing after a zone/job/sync.
function partyCare.GetSpellAvailability(now)
    now = now or os.clock();
    if now - availabilityCache.at < 0.25 then
        return availabilityCache.values;
    end

    local values = {};
    local jobs = local_jobs();
    if jobs == nil then
        availabilityCache = { at = now, values = values };
        return values;
    end

    local spellDataReady = bool_or_nil(safe_call(jobs.player, 'HasSpellData'));
    for spellName, spellInfo in pairs(STANDARD_SPELLS) do
        local levelUsable = usable_for_jobs(spellInfo, jobs);
        if levelUsable == false then
            values[spellName] = false;
        elseif spellDataReady == true then
            local learned = bool_or_nil(safe_call(jobs.player, 'HasSpell', spellInfo.id));
            if learned == false then
                values[spellName] = false;
            elseif learned == true then
                values[spellName] = levelUsable;
            end
        end
    end

    availabilityCache = { at = now, values = values };
    return values;
end

local function get_settings()
    if type(gConfig) == 'table' and type(gConfig.partyCare) == 'table' then
        return gConfig.partyCare;
    end
    return DEFAULT_SETTINGS;
end

local function get_statuses(buffs)
    if buffs == nil then return {}, false; end

    local statuses = {};
    local seen = {};
    local readable = type(buffs) == 'table';
    -- XIUI remote status packets are normally one-based, while local player
    -- buff arrays may expose the first entry at index zero.  Read both shapes.
    for index = 0, 32 do
        local ok, raw = pcall(function() return buffs[index]; end);
        if ok and raw ~= nil then
            readable = true;
            local statusId = tonumber(raw);
            if statusId == 255 then break; end
            if statusId ~= nil and statusId > 0 and not seen[statusId] then
                statuses[#statuses + 1] = statusId;
                seen[statusId] = true;
            end
        end
    end
    return statuses, readable;
end

local function has_status(statuses, targetStatus)
    for _, statusId in ipairs(statuses) do
        if statusId == targetStatus then return true; end
    end
    return false;
end

local function resolve_remedy(statuses, settings, availability)
    local remedies = type(settings.remedies) == 'table' and settings.remedies or DEFAULT_REMEDIES;
    local candidates = {};
    local seenRules = {};
    for _, statusId in ipairs(statuses) do
        local ruleId = STATUS_TO_REMEDY[statusId];
        local rule = ruleId and remedies[ruleId] or nil;
        if ruleId and rule and not seenRules[ruleId] and rule.enabled == true and
            type(rule.spell) == 'string' and rule.spell ~= '' and availability[rule.spell] ~= false then
            candidates[#candidates + 1] = {
                ruleId = ruleId,
                spell = rule.spell,
                priority = tonumber(rule.priority) or 0,
            };
            seenRules[ruleId] = true;
        end
    end
    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then return left.priority > right.priority; end
        return left.ruleId < right.ruleId;
    end);
    return candidates[1], candidates;
end

local function upkeep_for_member(memInfo)
    local serverId = tonumber(memInfo and memInfo.serverid);
    if serverId == nil or serverId <= 0 then return nil; end
    local state = observedUpkeep[serverId];
    if state == nil then
        state = {};
        observedUpkeep[serverId] = state;
    end
    return state;
end

local function get_upkeep_alert(hasPositiveStatus, statusKnown, observed, enabled, earlyEnabled, duration, early, now)
    if not enabled then return nil; end

    -- A positive icon proves the buff is active but does not expose its remaining
    -- time.  When XIUI observed this local cast, use that timer first so the
    -- requested final-15-second pulse is visible *before* the icon disappears.
    if observed and observed.startedAt then
        local remaining = (tonumber(observed.duration) or duration) - (now - observed.startedAt);
        if remaining > 0 then
            if earlyEnabled and remaining <= early then return 'expiring'; end
            return nil;
        end
        -- Once the observed interval ends, the status icon wins if it remains:
        -- it may have been refreshed by another caster or have a different duration.
        if hasPositiveStatus then return nil; end
        return 'missing';
    end

    -- Without an observed duration we can distinguish a confirmed active buff
    -- from a confirmed missing one, but must not invent an early countdown.
    if hasPositiveStatus then return nil; end
    if statusKnown then return 'missing'; end
    return nil;
end

function partyCare.GetMemberState(memInfo, memberSlot, now)
    now = now or os.clock();
    local settings = get_settings();
    if settings.enabled ~= true or memInfo == nil or memInfo.inzone ~= true then
        return { enabled = false };
    end

    local statuses, statusKnown = get_statuses(memInfo.buffs);
    local availability = partyCare.GetSpellAvailability(now);
    local remedy = nil;
    if settings.showRemedySuggestions ~= false and statusKnown then
        remedy = resolve_remedy(statuses, settings, availability);
    end

    local upkeep = upkeep_for_member(memInfo);
    local refresh = nil;
    local haste = nil;
    local eligibleForRefresh = (tonumber(memInfo.maxmp) or 0) >= (tonumber(settings.refreshMinMP) or 150);
    if availability.Refresh ~= false and eligibleForRefresh then
        refresh = get_upkeep_alert(
            has_status(statuses, REFRESH_STATUS_ID), statusKnown, upkeep and upkeep.refresh,
            settings.refreshPulseEnabled == true, settings.refreshEarlyEnabled ~= false,
            tonumber(settings.refreshDurationSeconds) or 150,
            tonumber(settings.refreshEarlySeconds) or 15, now
        );
    end
    if availability.Haste ~= false then
        haste = get_upkeep_alert(
            has_status(statuses, HASTE_STATUS_ID), statusKnown, upkeep and upkeep.haste,
            settings.hastePulseEnabled == true, settings.hasteEarlyEnabled ~= false,
            tonumber(settings.hasteDurationSeconds) or 180,
            tonumber(settings.hasteEarlySeconds) or 15, now
        );
    end

    -- Visual priority is intentional: actionable remedy alert (red), then
    -- Refresh (purple), then Haste (yellow).  Haste never replaces Refresh.
    local alertKind = nil;
    if remedy ~= nil then
        alertKind = 'remedy';
    elseif refresh ~= nil then
        alertKind = refresh == 'expiring' and 'refresh_expiring' or 'refresh_missing';
    elseif haste ~= nil then
        alertKind = haste == 'expiring' and 'haste_expiring' or 'haste_missing';
    end

    return {
        enabled = true,
        statuses = statuses,
        statusKnown = statusKnown,
        availability = availability,
        remedy = remedy,
        refresh = refresh,
        haste = haste,
        alertKind = alertKind,
    };
end

local function interpolate_color(fromColor, toColor, amount)
    local function channel(color, shift)
        return bit.band(bit.rshift(color, shift), 0xFF);
    end
    local a = math.floor(channel(fromColor, 24) + (channel(toColor, 24) - channel(fromColor, 24)) * amount);
    local r = math.floor(channel(fromColor, 16) + (channel(toColor, 16) - channel(fromColor, 16)) * amount);
    local g = math.floor(channel(fromColor, 8) + (channel(toColor, 8) - channel(fromColor, 8)) * amount);
    local b = math.floor(channel(fromColor, 0) + (channel(toColor, 0) - channel(fromColor, 0)) * amount);
    return bit.bor(bit.lshift(a, 24), bit.lshift(r, 16), bit.lshift(g, 8), b);
end

local function pulse_color(lowColor, highColor, now)
    local phase = (now % 1.0) * 2.0;
    if phase > 1.0 then phase = 2.0 - phase; end
    return interpolate_color(lowColor, highColor, phase);
end

function partyCare.GetNameColor(state, defaultColor, now)
    if state == nil or state.alertKind == nil then return defaultColor; end
    now = now or os.clock();
    if state.alertKind == 'remedy' then return 0xFFFF4A4A; end
    if state.alertKind == 'refresh_expiring' then return pulse_color(0xFF6D3FA0, 0xFFE0B8FF, now); end
    if state.alertKind == 'refresh_missing' then return 0xFF8350B8; end
    if state.alertKind == 'haste_expiring' then return pulse_color(0xFFB8860B, 0xFFFFFF9C, now); end
    if state.alertKind == 'haste_missing' then return 0xFFE0B62A; end
    return defaultColor;
end

function partyCare.GetRemedyLabel(state)
    if state == nil or state.remedy == nil then return nil; end
    return state.remedy.spell;
end

local function target_token(memberSlot)
    if type(memberSlot) ~= 'number' or memberSlot < 0 or memberSlot > 17 or memberSlot ~= math.floor(memberSlot) then
        return nil;
    end
    if memberSlot <= 5 then return string.format('<p%d>', memberSlot); end
    if memberSlot <= 11 then return string.format('<a1%d>', memberSlot - 6); end
    return string.format('<a2%d>', memberSlot - 12);
end

local function safe_spell_name(spellName)
    return type(spellName) == 'string' and spellName:match("^[%a%d %-%']+$") ~= nil;
end

function partyCare.BuildManualCommand(spellName, memberSlot)
    if not safe_spell_name(spellName) then return nil; end
    local target = target_token(memberSlot);
    if target == nil then return nil; end
    return string.format('/ma "%s" %s', spellName, target);
end

function partyCare.DispatchManualSpell(spellName, memberSlot)
    local command = partyCare.BuildManualCommand(spellName, memberSlot);
    if command == nil or AshitaCore == nil or type(AshitaCore.GetChatManager) ~= 'function' then return false; end
    local chat = AshitaCore:GetChatManager();
    if chat == nil or type(chat.QueueCommand) ~= 'function' then return false; end
    -- The caller is always a click or wheel event in display.lua.  Do not add
    -- retry, automation, target changes, or background dispatch here.
    chat:QueueCommand(1, command);
    return true;
end

local function dispatch_binding(binding, memberSlot)
    if type(binding) ~= 'table' or binding.enabled ~= true then return false; end
    -- Deliberately do not block a deliberate manual action based on an aged
    -- availability cache.  The game remains the final authority.
    return partyCare.DispatchManualSpell(binding.spell, memberSlot);
end

function partyCare.HandleHoverWheel(state, memberSlot, wheelDelta)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    if wheelDelta > 0 then return dispatch_binding(settings.wheelUp, memberSlot); end
    if wheelDelta < 0 then return dispatch_binding(settings.wheelDown, memberSlot); end
    return false;
end

local function mouse_binding(settings, button)
    local bindingKeys = {
        [0] = 'left', [1] = 'right', [2] = 'middle', [3] = 'mouse4', [4] = 'mouse5',
    };
    local bindingKey = bindingKeys[button];
    return bindingKey and settings[bindingKey] or nil;
end

function partyCare.IsMouseButtonBound(button)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    local binding = mouse_binding(settings, button);
    return type(binding) == 'table' and binding.enabled == true;
end

function partyCare.HandleMouseButton(memberSlot, button)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    return dispatch_binding(mouse_binding(settings, button), memberSlot);
end

function partyCare.DispatchRemedy(state, memberSlot)
    if state == nil or state.remedy == nil then return false; end
    return partyCare.DispatchManualSpell(state.remedy.spell, memberSlot);
end

-- Record an eligible local upkeep spell as it begins.  XIUI's draw path may
-- clear a completed cast bar before the corresponding finish packet arrives, so
-- pending information is intentionally stored separately from visual cast bars.
function partyCare.ObserveStartedSpell(casterServerId, spellId, targetServerId, now)
    if tonumber(spellId) ~= STANDARD_SPELLS.Refresh.id and tonumber(spellId) ~= STANDARD_SPELLS.Haste.id then return; end
    local casterId = tonumber(casterServerId);
    local targetId = tonumber(targetServerId);
    if casterId == nil or casterId <= 0 or targetId == nil or targetId <= 0 then return; end
    pendingUpkeepCasts[casterId] = { spellId = tonumber(spellId), targetServerId = targetId, startedAt = now or os.clock() };
end

-- Resolve or cancel the matching locally-observed cast.  Only a non-interrupted
-- finish records a maintenance interval.  This never sends a game command.
function partyCare.ObserveSpellResult(casterServerId, interrupted, now)
    local casterId = tonumber(casterServerId);
    local pending = casterId and pendingUpkeepCasts[casterId] or nil;
    if pending == nil then return; end
    pendingUpkeepCasts[casterId] = nil;
    if interrupted then return; end
    partyCare.ObserveCompletedSpell(pending.spellId, pending.targetServerId, now or os.clock());
end

-- Called only when a complete, non-interrupted Refresh/Haste action has been
-- observed by XIUI's existing packet path.  Positive status icons subsequently
-- override these timers when available.
function partyCare.ObserveCompletedSpell(spellId, targetServerId, now)
    local serverId = tonumber(targetServerId);
    if serverId == nil or serverId <= 0 then return; end
    local settings = get_settings();
    now = now or os.clock();
    local upkeep = observedUpkeep[serverId] or {};
    if tonumber(spellId) == STANDARD_SPELLS.Refresh.id then
        upkeep.refresh = { startedAt = now, duration = tonumber(settings.refreshDurationSeconds) or 150 };
    elseif tonumber(spellId) == STANDARD_SPELLS.Haste.id then
        upkeep.haste = { startedAt = now, duration = tonumber(settings.hasteDurationSeconds) or 180 };
    else
        return;
    end
    observedUpkeep[serverId] = upkeep;
end

function partyCare.Reset()
    observedUpkeep = {};
    pendingUpkeepCasts = {};
    availabilityCache = { at = 0, values = {} };
end

-- Small, pure helpers exposed solely for deterministic local regression tests.
partyCare._test = {
    get_statuses = get_statuses,
    resolve_remedy = resolve_remedy,
    target_token = target_token,
    default_remedies = DEFAULT_REMEDIES,
    standard_spells = STANDARD_SPELLS,
    status_to_remedy = STATUS_TO_REMEDY,
    pending_upkeep_casts = function() return pendingUpkeepCasts; end,
};

return partyCare;
