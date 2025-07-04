#!/usr/bin/env bash
set -euo pipefail

# Test script to verify selective rebuilding works correctly
# This test proves that changes to unrelated crates don't trigger rebuilds

echo "🧪 Testing selective rebuilding..."

# Build crate-a and record the hash
echo "📦 Building crate-a initially..."
HASH1=$(nix build .#crate-a --print-out-paths --no-link)
echo "Initial hash: $HASH1"

# Change an unrelated crate (crate-d doesn't affect crate-a)
echo "🔧 Modifying unrelated crate (crate-d)..."
echo "// Test change $(date)" >> crate-d/src/lib.rs

# Build crate-a again - hash should be the same
echo "📦 Building crate-a after unrelated change..."
HASH2=$(nix build .#crate-a --print-out-paths --no-link)
echo "Hash after unrelated change: $HASH2"

if [ "$HASH1" = "$HASH2" ]; then
    echo "✅ PASS: Unrelated change did not trigger rebuild"
else
    echo "❌ FAIL: Unrelated change triggered rebuild"
    echo "Expected: $HASH1"
    echo "Got:      $HASH2"
    exit 1
fi

# Change a dependency (crate-c affects crate-a through crate-b)
echo "🔧 Modifying dependency crate (crate-c)..."
echo "// Test change $(date)" >> crate-c/src/lib.rs

# Build crate-a again - hash should be different
echo "📦 Building crate-a after dependency change..."
HASH3=$(nix build .#crate-a --print-out-paths --no-link)
echo "Hash after dependency change: $HASH3"

if [ "$HASH1" != "$HASH3" ]; then
    echo "✅ PASS: Dependency change triggered rebuild"
else
    echo "❌ FAIL: Dependency change did not trigger rebuild"
    echo "Expected different from: $HASH1"
    echo "Got:                    $HASH3"
    exit 1
fi

echo "🎉 All tests passed! Selective rebuilding is working correctly."
echo ""
echo "Summary:"
echo "- Unrelated changes (crate-d) do NOT trigger rebuilds of crate-a"
echo "- Dependency changes (crate-c) DO trigger rebuilds of crate-a"