--[[
    XIUI PartyCare Enemy-List Feature Module

    Optional manual offensive spell controls for XIUI's native Enemy List.
    This module is intentionally separate from party-list PartyCare support actions.
    It never selects, retargets, queues retries, or casts automatically.  A command
    can be queued only by an explicit click or wheel action over the currently
    selected enemy-list entry.
]]

require('common');

local enemyCare = {};

local DEFAULT_SETTINGS = {
    enabled = false,
    hoverActionsEnabled = false,
    left = { enabled = false, spell = 'Blind' },
    right = { enabled = false, spell = 'Slow' },
    middle = { enabled = false, spell = 'Dia II' },
    mouse4 = { enabled = false, spell = 'Bind' },
    mouse5 = { enabled = false, spell = 'Gravity' },
    wheelUp = { enabled = true, spell = 'Dia' },
    wheelDown = { enabled = true, spell = 'Paralyze' },
};

local function get_settings()
    if type(gConfig) == 'table' and type(gConfig.enemyCare) == 'table' then
        return gConfig.enemyCare;
    end
    return DEFAULT_SETTINGS;
end

local function safe_spell_name(spellName)
    return type(spellName) == 'string' and spellName:match("^[%a%d %-%']+$") ~= nil;
end

local function target_is_current(enemyIndex, currentTargetIndex, subTargetActive)
    -- `<t>` always refers to the presently selected target.  Do not infer a new
    -- target from the hovered card and do not act while subtarget selection is
    -- open; both safeguards preserve completely manual target control.
    if subTargetActive == true then return false; end
    local enemy = tonumber(enemyIndex);
    local current = tonumber(currentTargetIndex);
    return enemy ~= nil and current ~= nil and enemy > 0 and enemy == current;
end

function enemyCare.BuildManualCommand(spellName, enemyIndex, currentTargetIndex, subTargetActive)
    if not safe_spell_name(spellName) then return nil; end
    if not target_is_current(enemyIndex, currentTargetIndex, subTargetActive) then return nil; end
    return string.format('/ma "%s" <t>', spellName);
end

function enemyCare.DispatchManualSpell(spellName, enemyIndex, currentTargetIndex, subTargetActive)
    local command = enemyCare.BuildManualCommand(spellName, enemyIndex, currentTargetIndex, subTargetActive);
    if command == nil or AshitaCore == nil or type(AshitaCore.GetChatManager) ~= 'function' then return false; end
    local chat = AshitaCore:GetChatManager();
    if chat == nil or type(chat.QueueCommand) ~= 'function' then return false; end

    -- This function is called only from an explicit ImGui click or wheel event.
    -- `/ma ... <t>` retains the user's current target; it never issues `/target`.
    chat:QueueCommand(1, command);
    return true;
end

local function mouse_binding(settings, button)
    local bindingKeys = {
        [0] = 'left', [1] = 'right', [2] = 'middle', [3] = 'mouse4', [4] = 'mouse5',
    };
    local bindingKey = bindingKeys[button];
    return bindingKey and settings[bindingKey] or nil;
end

local function dispatch_binding(binding, enemyIndex, currentTargetIndex, subTargetActive)
    if type(binding) ~= 'table' or binding.enabled ~= true then return false; end
    -- Availability can change around job/Level Sync updates.  This is a deliberate
    -- manual action, so let the game remain the final authority for eligibility.
    return enemyCare.DispatchManualSpell(binding.spell, enemyIndex, currentTargetIndex, subTargetActive);
end

function enemyCare.IsMouseButtonBound(button)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    local binding = mouse_binding(settings, button);
    return type(binding) == 'table' and binding.enabled == true;
end

function enemyCare.HandleMouseButton(enemyIndex, currentTargetIndex, subTargetActive, button)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    return dispatch_binding(mouse_binding(settings, button), enemyIndex, currentTargetIndex, subTargetActive);
end

function enemyCare.HandleHoverWheel(enemyIndex, currentTargetIndex, subTargetActive, wheelDelta)
    local settings = get_settings();
    if settings.enabled ~= true or settings.hoverActionsEnabled ~= true then return false; end
    if wheelDelta > 0 then
        return dispatch_binding(settings.wheelUp, enemyIndex, currentTargetIndex, subTargetActive);
    end
    if wheelDelta < 0 then
        return dispatch_binding(settings.wheelDown, enemyIndex, currentTargetIndex, subTargetActive);
    end
    return false;
end

-- Pure helpers exposed solely for deterministic local regression tests.
enemyCare._test = {
    target_is_current = target_is_current,
    safe_spell_name = safe_spell_name,
};

return enemyCare;
