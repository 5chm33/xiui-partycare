# Upstream and Local Delta Boundary

This repository contains a bundled XIUI tree and identifies the package as an **XIUI 1.8.3** build. However, the repository does **not** currently record an upstream repository URL, exact upstream commit, submodule, vendor manifest, or license/notice establishing a machine-verifiable upstream baseline.

## What can be stated accurately

- The first commit in this repository is `c7fea698d71e9ad9d26e600a3ac66ace8c7a1653` (`Initial XIUI PartyCare fusion v0.3.0`). It already contains the bundled XIUI tree and PartyCare integration.
- The local history after that commit documents PartyCare, Enemy List, persistence, and Dilation Ring changes, but it is **not** an upstream XIUI comparison.
- Consequently, no file in this repository should be described as unchanged from, derived from, or equivalent to a particular upstream XIUI revision unless that revision is recorded and independently compared.

## Local maintenance delta in this branch

This maintenance branch makes only the following scoped changes:

1. Removes the invalid semicolon after `elseif ... then` in `XIUI/libs/hp.lua`, restoring parsing on Lua 5.1-compatible interpreters such as MoonJIT.
2. Makes `tests/test_partylist_position_persistence.lua` resolve `XIUI/` relative to the test file rather than a `/home/ubuntu/...` checkout.
3. Adds a portable syntax-and-regression runner, a focused HP-color regression test, and CI that performs a full Lua 5.4 syntax check plus deterministic tests on a pinned MoonJIT 2.1 family source revision.
4. Makes the PartyCare test's local bit-operation mock parse on Lua 5.1/MoonJIT as well as Lua 5.4. This affects test scaffolding only, not XIUI runtime code.

These statements describe **repository-local changes only**. They do not establish ownership, licensing, or a complete diff against XIUI upstream.

The full bundled tree is not MoonJIT/Lua 5.1 parse-compatible: `XIUI/modules/satchel/containerlogic.lua` uses Lua 5.2 `goto` labels. The MoonJIT CI scope is deliberately limited to the repaired `XIUI/libs/hp.lua` compatibility target and the deterministic test suite; the Lua 5.4 CI job syntax-checks every tracked Lua file. This boundary is explicit to avoid implying unsupported whole-tree MoonJIT compatibility.

## Required provenance follow-up

To make an upstream/local comparison reproducible, record the official upstream XIUI URL, the exact base commit or release checksum, applicable licenses/notices, and a repeatable diff or patch-generation command. Until then, downstream users should treat the bundled XIUI tree as an unverified vendored baseline rather than a verified upstream mirror.
