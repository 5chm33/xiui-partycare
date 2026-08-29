# Release Notes

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
