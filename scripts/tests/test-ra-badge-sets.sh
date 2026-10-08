#!/usr/bin/env bash
# Host unit test for workspace/all/common/ra_badge_sets.c (per-game "all
# badges cached" markers, issue #132). Nothing is built for a device.
set -euo pipefail
cd "$(dirname "$0")/../.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cc -std=c11 -Wall -Wextra -Werror -O1 -fsanitize=address,undefined \
    -I workspace/all/common \
    -o "$TMP/ra_badge_sets_test" \
    scripts/tests/ra_badge_sets/ra_badge_sets_test.c \
    workspace/all/common/ra_badge_sets.c
mkdir -p "$TMP/ra"
"$TMP/ra_badge_sets_test" "$TMP/ra"
