#!/usr/bin/env sh
# Run tracked Lua syntax checks and deterministic regression tests from any directory.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
lua_bin=${LUA_BIN:-lua}
syntax_scope=${LUA_SYNTAX_SCOPE:-full}

if ! command -v "$lua_bin" >/dev/null 2>&1; then
    printf 'error: Lua interpreter not found: %s\n' "$lua_bin" >&2
    exit 127
fi

printf 'Interpreter: '
"$lua_bin" -v 2>&1

cd "$repo_root"

case "$syntax_scope" in
    full)
        printf '%s\n' 'Syntax-checking all tracked Lua files...'
        syntax_files=$(git ls-files '*.lua' | LC_ALL=C sort)
        ;;
    moonjit)
        # The vendored Satchel module uses Lua 5.2 goto labels, which MoonJIT
        # cannot parse. Check the repaired 5.1-compatible HP module and every
        # deterministic test here; Lua 5.4 performs the full-tree check.
        printf '%s\n' 'Syntax-checking MoonJIT compatibility targets...'
        syntax_files=$( {
            printf '%s\n' 'XIUI/libs/hp.lua'
            git ls-files 'tests/*.lua'
        } | LC_ALL=C sort -u)
        ;;
    *)
        printf 'error: unsupported LUA_SYNTAX_SCOPE: %s (expected full or moonjit)\n' "$syntax_scope" >&2
        exit 2
        ;;
esac

printf '%s\n' "$syntax_files" | while IFS= read -r source_file; do
    test -n "$source_file" || continue
    "$lua_bin" -e "assert(loadfile([[$source_file]]))"
done

printf '%s\n' 'Running deterministic regression tests...'
git ls-files 'tests/test_*.lua' | LC_ALL=C sort | while IFS= read -r test_file; do
    printf '==> %s\n' "$test_file"
    "$lua_bin" "$test_file"
done

printf '%s\n' 'PASS: syntax and deterministic regression suite'
