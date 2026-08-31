# Release Notes

## v0.11.0 — Teammate Dispel Cue Cleanup

This targeted correction closes the remaining stale red-cue path reported after a **teammate** dispelled a confirmed enemy positive effect.

| Area | Included behavior |
|---|---|
| Cross-player cast results | XIUI now clears the affected Enemy List cue when any completed cast result explicitly reports that the target’s status disappeared, even if the action parameter carries a spell/action value rather than the removed status icon. |
| Basic message fallback | The matching standard battle-message form also clears the target card when it is delivered separately from the action result. |
| Scope | This fallback is restricted to explicit cast-removal messages. It does not clear unrelated positive-effect cues merely because another action occurred. |
| Safety | The change affects only the visual cue cache; it does not target, cast, retry, or modify the manual Dispel button. |

### Verification

All XIUI Lua sources passed syntax validation. The expanded enemy positive-effect watcher suite covers specific icon removal, iconless local Dispel, iconless teammate action results, and iconless teammate basic messages. The full regression suite and clean release archive validation passed.

## v0.10.0 — Dispel Cue Cleanup and Enemy List Deaggro Retirement

This cleanup release removes two stale-state cases confirmed in live testing while preserving the manual-only action model.

| Area | Included behavior |
|---|---|
| External Dispel cleanup | A tracked enemy cue now clears when **any player** generates a completed action result that explicitly removes the recorded positive status—not only when the local player uses Dispel. |
| Iconless local Dispel result | The existing conservative fallback remains: an explicit completed local Dispel removal result without an icon clears the card’s cue set to avoid a stale prompt. |
| Linked-mob cleanup | A tracked Enemy List card is removed immediately when an authoritative claim update reports that it is yellow/unclaimed or claimed outside the party. |
| Cue cleanup with card removal | Deaggro retirement also removes retained positive-effect cue state and cached labels for that mob. |
| Safety | No cleanup path changes targets, sends commands, or automatically casts a spell. |

### Verification

All XIUI Lua sources passed syntax validation. The PartyCare, Enemy List action, positive-effect watcher, remedy visual/layout, and new Enemy List deaggro-retirement test suites passed. The release archive was validated from a clean extraction.

## v0.9.0 — Visible Remedy Label and Pulsing Manual-Dispel Cue

This visual refinement ensures that the already-working manual action areas are visibly readable in XIUI themes and makes a confirmed enemy positive effect easier to notice without changing targeting or cast safety.

| Area | Included behavior |
|---|---|
| Remedy label visibility | The native Party List remedy button remains the input control, while a final XIUI foreground draw pass paints its red background, border, and `REMEDY: <spell>` text above themed card/background layers. |
| No new click layer | The foreground paint is visual-only. It cannot block clicks, retarget, or alter the established manual remedy dispatch path. |
| Enemy visual cue | Replaces the outer red outline with a light, pulsing red background inside the affected Enemy List card. Text, HP bars, and native target borders remain readable on top. |
| Manual Dispel clearing | A completed Dispel result that reports a status removal clears the matching cue at once. An iconless successful removal result clears the card’s retained cue set to avoid stale prompts. |
| Manual-only safety | The cue remains a visual reminder. Only the blue `DISPEL` button or a deliberately configured enemy hover binding can send a spell command. |

### Verification

All XIUI Lua sources passed syntax validation. The PartyCare, Enemy List action, enemy positive-effect watcher, and native remedy-row visual/layout suites passed. The release archive was validated from a clean extraction.

## v0.8.0 — Native Remedy Row Restoration and Expanded Enemy Cue Evidence

This regression-correction release restores the Party List remedy action to XIUI’s stable native input path and expands the conservative direct-effect evidence used by the visual Dispel cue.

| Area | Included behavior |
|---|---|
| Remedy action | Removes the separate remedy overlay window and restores the red `REMEDY: <spell>` strip directly inside the existing Party List window, in its reserved row beneath the affected card. |
| Input reliability | The restored native button follows XIUI's established ImGui window/input path. It remains an explicit single manual remedy dispatch with no targeting, retries, or autonomous casting. |
| Positive-effect cue | A completed enemy self-action with a known positive status icon now activates the red cue even if HorizonXI supplies an unlisted result message. Confirmed positive statuses in `AdditionalEffect` are also recognized. |
| Conservative exclusions | Cast starts, effects applied to another target, and direct negative/debuff status IDs remain excluded from the red cue. |
| Regression coverage | Updates the remedy-layout contract for the native action row and adds direct-message-variant and additional-effect cases to the enemy positive-effect watcher suite. |

### Verification

All XIUI Lua sources parsed successfully. The PartyCare eligibility/action, Enemy List action, enemy positive-effect watcher, and native remedy-row layout tests passed. The release archive was validated from a clean extraction.

## v0.7.0 — Confirmed Enemy Positive-Effect Dispel Cue

This enhancement adds a red visual prompt for manual Dispel decisions while preserving the existing no-automation safety model.

| Area | Included behavior |
|---|---|
| Direct evidence only | A new watcher records a cue only when a completed action packet confirms a known positive effect was applied to the enemy actor itself. Cast starts, effects on another target, and explicit non-buff/debuff result IDs are rejected. |
| Visual cue | The matching XIUI Enemy List card pulses a red outer border. No command is queued, target is changed, or spell is selected automatically. |
| Cue clearing | Matching effect-removal and death packets clear the cue; an exposed, configurable maximum duration prevents a stale visual prompt if no removal signal reaches XIUI. |
| Manual Dispel remains manual | The existing blue current-target `DISPEL` button and user-configured hover bindings remain the only ways to cast Dispel. |
| `/xiui` controls | Under **Enemy List → Manual Offensive Hover Spells**, enable or disable **Blink Red for Confirmed Enemy Positive Effects** and set its maximum cue duration. |
| Scope honesty | This is a manual “inspect/Dispel” prompt. The underlying packet confirms a positive effect, but the cue intentionally does not guarantee every effect is dispellable. |

### Verification

All XIUI Lua sources passed syntax validation. A new deterministic watcher suite verifies self-target status-on acceptance, cast-start/other-target/non-buff rejection, effect-loss removal, monster-skill confirmation, and zone cleanup. The existing PartyCare, Enemy List action, and remedy-overlay suites also passed. The release archive was validated from a clean extraction.

## v0.6.0 — Remedy Action Overlay Correction

This focused correction release replaces the remedy control’s still-clipped in-window placement with a dedicated post-window overlay.

| Area | Included behavior |
|---|---|
| Remedy rendering | The red `REMEDY: <spell>` action is now rendered in its own fixed, transparent XIUI overlay window after the PartyList parent window is closed for the frame. |
| Visibility | The overlay sits above native party-card, status-icon, and background draw layers rather than within their clipped content region. It keeps a dedicated full-width strip below the affected card. |
| Layout | The PartyList continues reserving the button height, so the remedy strip does not collide with the next party member. |
| Manual action safety | Clicking the overlay calls the existing remedy dispatcher exactly once; it does not target, retarget, retry, or automatically cast. |
| Regression coverage | Adds `tests/test_remedy_overlay_layout.lua`, which verifies the top-layer overlay architecture, reserved space, absence of the old inline button, and post-PartyList render order. |

### Verification

All XIUI Lua files parsed successfully. The PartyCare eligibility/action test, Enemy List action test, and remedy-overlay layout contract test passed. The release archive was validated from a clean extraction.

## v0.5.0 — Remedy Visibility and Manual Current-Target Dispel

This correction release makes the party remedy action unmistakably visible and adds a manual Dispel action to the selected Enemy List card.

| Area | Included behavior |
|---|---|
| Remedy visibility | Replaces the fragile name-row remedy label with a full-width red `REMEDY: <spell>` action strip immediately below the affected party card. The party-window layout now reserves dedicated space for it. |
| Existing profiles | A missing legacy `showRemedyButtons` setting now defaults to enabled unless the player explicitly disables it in `/xiui` → **Party List**. |
| Enemy List Dispel | Adds an optional blue `DISPEL` strip on the Enemy List card that is already the selected `<t>` target. It is separately controlled under `/xiui` → **Enemy List** → **Manual Offensive Hover Spells**. |
| Safety | Clicking either action queues exactly one manual `/ma "Spell" <target>` command. Neither action selects a target, retargets, retries, or casts automatically. |
| Honest effect scope | The Dispel strip is a manual “potential buff” action; it does not claim that XIUI detected an enemy positive effect, because that data is not authoritative in the available enemy-list feed. |

### Verification

All XIUI Lua sources passed syntax validation. The PartyCare test suite passed, and the Enemy List suite now also verifies the manual Dispel-button visibility gate and `/ma "Dispel" <t>` dispatch, along with wrong-card, subtarget, and disabled-feature safety rejections. The packaged archive was subsequently validated from a clean extraction.

## v0.4.0 — Separate Enemy List Offensive Hover Actions

This release adds a second, independent manual-action layer to XIUI’s native **Enemy List**. It is intentionally separate from Party List healing, support, remedy, and Refresh/Haste settings.

| Area | Included behavior |
|---|---|
| Native XIUI placement | Controls live under `/xiui` → **Enemy List** → **Manual Offensive Hover Spells**. No additional standalone window or PartyCare skin is added. |
| Independent bindings | Left click, right click, middle click, Mouse 4, Mouse 5, Wheel Up, and Wheel Down each have their own enable switch and offensive/enfeebling spell selector. Wheel Up defaults to **Dia**; Wheel Down defaults to **Paralyze**. |
| Spell choices | Includes Dia, Bio, Blind, Paralyze, Slow, Gravity, Bind, Sleep, Silence, Dispel, selected elemental enfeebles, Aspir, Drain, and their available listed variants. |
| Current-target safeguard | A spell is queued only after a deliberate hover click/wheel event on the Enemy List card that is already the current `<t>` target. Hovering a different enemy never retargets or casts. |
| Click-to-target compatibility | When an enemy-care binding cannot dispatch because the card is not the current target, XIUI’s standard left-click **Click to Target** behavior remains available. |

> **Manual-action safety:** This feature never changes target selection, performs background retries, chooses spells automatically, or reacts to enemy buffs. It queues only the user’s configured spell and only after an explicit input over the currently selected enemy card.

### Verification

All XIUI Lua sources passed syntax validation. `tests/test_enemylistcare_integration.lua` passed deterministic coverage for every supported mouse binding, safe `/ma "Spell" <t>` construction, disabled-feature behavior, wrong-card rejection, and subtarget-mode rejection. The existing PartyCare party-list regression suite also remains part of the full validation run.

### Known Scope

This adds manual offensive/enfeebling spell dispatch only. It does not restore the prior experimental automatic enemy-Dispel recommendation behavior, because enemy-buff visibility is not reliable enough to make automatic recommendations authoritative.

## v0.3.0 — XIUI 1.8.3 PartyCare Fusion

This first release packages a separate XIUI 1.8.3 build that embeds optional PartyCare-style manual care features directly into XIUI’s native party list. It does not modify or supersede the standalone PartyCare addons.

| Area | Included behavior |
|---|---|
| Native XIUI presentation | No PartyCare standalone panel or alternate skin. The features live under `/xiui` → **Party List**. |
| Manual spell actions | Independent left, right, middle, Mouse 4, Mouse 5, wheel-up, and wheel-down bindings. Wheel-up defaults to Refresh and wheel-down defaults to Haste. |
| Remedy controls | A clearly visible red inline `Remedy: <spell>` button appears only for a verified, directly mapped status with an eligible local spell. |
| Eligibility | Uses only the local player’s effective main job, subjob, Level Sync level, and learned spellbook. Party-member jobs are never used. |
| Upkeep cues | Remedy red → Refresh purple → Haste yellow. Missing cues are solid; observed local casts pulse during the configured final lead time. |

The v0.3.0 correction resolves the early-warning ordering bug that suppressed the configurable 15-second Refresh/Haste pulse when a positive status icon was still visible. For a locally cast Refresh or Haste that XIUI observes after load, the native name cue now pulses during the final 15 seconds while the corresponding status icon remains active. At the expected end time, a still-visible icon prevents a false missing alert; when the icon drops, the solid missing cue returns.

> **Manual-action safety:** Neither this integration nor its upkeep timers auto-cast or change targets. A spell command is queued only after an explicit configured mouse input or an explicit remedy-button click.

### Verification

All XIUI Lua sources passed syntax validation. The included deterministic suite (`tests/test_partycare_integration.lua`) passed, covering remedy eligibility and priority, safe command construction, all configured mouse inputs, pulse timing, positive-status handling, interruption handling, and re-alerting after expiration.

### Known Scope

The previous experimental enemy-Dispel box is intentionally not included, because enemy-buff visibility is not authoritative enough to expose it as a reliable party-care action.
