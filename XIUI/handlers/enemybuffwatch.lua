--[[
* XIUI Enemy Positive-Effect Watcher
* Tracks only packet-confirmed positive effects that are applied to the action
* actor itself. It is a visual cue source for manual Dispel decisions; it does
* not attempt to classify every effect as dispellable and never issues commands.
]]--

require('common');
local buffTable = require('libs.bufftable');

local M = {};

-- Packet messages that explicitly report a target gaining or receiving an
-- effect. These mirror XIUI's established pet-status tracker classifications.
local STATUS_ON_MESSAGES = {
    [186] = true, -- uses skill / gains effect
    [203] = true, -- is status
    [205] = true, -- gains effect
    [230] = true, [236] = true, [237] = true, -- magic gains/has/receives effect
    [242] = true, [243] = true, -- skill status / receives effect
    [266] = true, [277] = true, [278] = true, -- target gains/has/receives effect
    [374] = true, -- status spikes
};

-- Explicit removal signals.  We clear the matching positive effect immediately
-- whenever the packet contains its effect icon; a bounded fallback prevents a
-- stale visual cue when an exact removal packet is unavailable.
local STATUS_OFF_MESSAGES = {
    [64] = true, [159] = true, [168] = true, [204] = true, [206] = true,
    [321] = true, [322] = true, [341] = true, [342] = true, [343] = true,
    [344] = true, [350] = true, [378] = true, [426] = true, [427] = true,
    [531] = true, [647] = true, [805] = true, [806] = true,
};
local DISPEL_SPELL_ID = 260;
local DEATH_MESSAGES = {
    [6] = true, [20] = true, [97] = true, [113] = true, [406] = true, [605] = true, [646] = true,
};

-- A cue deliberately fades after five minutes if no removal information is
-- delivered. It is only a reminder to manually inspect/use Dispel, never a
-- statement that the effect is still present or dispellable.
local FALLBACK_CUE_SECONDS = 300;
local activeEffects = {};

local function valid_effect_id(effectId)
    effectId = tonumber(effectId);
    return effectId ~= nil and effectId > 0 and effectId < 1000 and buffTable.IsBuff(effectId) == true;
end

local function record_effect(serverId, effectId)
    if serverId == nil or not valid_effect_id(effectId) then return; end
    if activeEffects[serverId] == nil then activeEffects[serverId] = {}; end
    activeEffects[serverId][effectId] = os.time();
end

local function remove_effect(serverId, effectId)
    if serverId == nil or effectId == nil or activeEffects[serverId] == nil then return; end
    activeEffects[serverId][effectId] = nil;
    if next(activeEffects[serverId]) == nil then activeEffects[serverId] = nil; end
end

local function clear_target(serverId)
    if serverId ~= nil then activeEffects[serverId] = nil; end
end

function M.HandleActionPacket(actionPacket)
    if actionPacket == nil or actionPacket.UserId == nil then return; end
    -- Only completed magic/monster-skill results provide an effect outcome;
    -- cast-start packets are intentionally ignored to avoid false alerts.
    if actionPacket.Type ~= 4 and actionPacket.Type ~= 11 then return; end

    for _, target in pairs(actionPacket.Targets or {}) do
        -- Effect removals can be reported in an action result rather than the
        -- separate basic-message stream. Honor a specific removed icon from
        -- *any* actor (including another party member's Dispel), because the
        -- cue belongs to the affected enemy, not to the player who removed it.
        -- An iconless removal clears all retained cue state only for a completed
        -- Dispel result, avoiding a stale prompt without guessing at other
        -- effects that might still be active.
        for _, action in pairs(target.Actions or {}) do
            local removedEffectId = action.Param;
            if STATUS_OFF_MESSAGES[action.Message] and valid_effect_id(removedEffectId) then
                remove_effect(target.Id, removedEffectId);
            elseif actionPacket.Type == 4 and tonumber(actionPacket.Param) == DISPEL_SPELL_ID
                and STATUS_OFF_MESSAGES[action.Message] then
                clear_target(target.Id);
            end

            local additional = action.AdditionalEffect;
            if additional and STATUS_OFF_MESSAGES[additional.Message] and valid_effect_id(additional.Param) then
                remove_effect(target.Id, additional.Param);
            end
        end

        -- A self-applied effect on the actor is the direct evidence that an
        -- enemy card may need a manual Dispel check. Effects on other targets
        -- are deliberately ignored.
        if target.Id == actionPacket.UserId then
            for _, action in pairs(target.Actions or {}) do
                local effectId = action.Param;
                -- On a completed enemy self-action, a direct positive status
                -- icon is authoritative regardless of the result-message
                -- variant used by a HorizonXI server. Restricting this solely
                -- to a fixed message allow-list missed valid Cocoon/Defense
                -- Boost-style results on some packet paths.
                if valid_effect_id(effectId) then
                    record_effect(actionPacket.UserId, effectId);
                elseif STATUS_ON_MESSAGES[action.Message] then
                    -- Only fall back to spell metadata if the packet omitted a
                    -- plausible effect ID. An explicit non-buff/debuff ID must
                    -- not be reinterpreted as a positive effect.
                    local numericEffectId = tonumber(effectId);
                    if (numericEffectId == nil or numericEffectId <= 0 or numericEffectId >= 1000)
                        and actionPacket.Type == 4 then
                        record_effect(actionPacket.UserId, buffTable.GetBuffIdBySpellId(actionPacket.Param));
                    end
                end

                -- Some abilities report their gained status as an additional
                -- result. Treat it identically, but still only for completed
                -- self-applied actions and known positive status icons.
                local additional = action.AdditionalEffect;
                if additional and valid_effect_id(additional.Param) then
                    record_effect(actionPacket.UserId, additional.Param);
                end
            end
        end
    end
end

function M.HandleMessagePacket(messagePacket)
    if messagePacket == nil then return; end
    local targetId = messagePacket.target;
    local senderId = messagePacket.sender;
    local effectId = messagePacket.param;

    if DEATH_MESSAGES[messagePacket.message] then
        clear_target(targetId);
        clear_target(senderId);
        return;
    end

    if STATUS_OFF_MESSAGES[messagePacket.message] and effectId ~= nil then
        -- Depending on packet flavor, the affected entity may be represented
        -- as target or sender. Clearing both is safe because IDs must match an
        -- effect that this watcher previously confirmed.
        remove_effect(targetId, effectId);
        remove_effect(senderId, effectId);
    end
end

function M.HandleZonePacket()
    activeEffects = {};
end

-- Removes retained cue state for one Enemy List entry that XIUI has confirmed
-- is no longer party-claimed. This is visual cleanup only.
function M.ClearTarget(serverId)
    clear_target(serverId);
end

-- Returns true plus the most recently observed effect ID/age for a live cue.
-- No caller should infer that a true result guarantees the effect is dispellable.
function M.GetRecentPositiveEffect(serverId, maxSeconds)
    local effects = serverId ~= nil and activeEffects[serverId] or nil;
    if effects == nil then return false; end

    local now = os.time();
    local maxAge = tonumber(maxSeconds) or FALLBACK_CUE_SECONDS;
    local newestEffect, newestAt = nil, nil;
    for effectId, seenAt in pairs(effects) do
        if now - seenAt <= maxAge then
            if newestAt == nil or seenAt > newestAt then
                newestEffect, newestAt = effectId, seenAt;
            end
        else
            effects[effectId] = nil;
        end
    end
    if next(effects) == nil then activeEffects[serverId] = nil; end
    if newestEffect == nil then return false; end
    return true, newestEffect, now - newestAt;
end

M._test = {
    valid_effect_id = valid_effect_id,
};

return M;
