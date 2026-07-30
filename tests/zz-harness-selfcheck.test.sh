#!/usr/bin/env bash
# Proves assert_* actually fail. make doctor and audit.sh both reported failures
# while exiting 0 for months; the test runner must not join them.
set -u
source "$(dirname "$0")/assert.sh"
( assert_eq a b "should fail" ) && { echo "FAIL: assert_eq did not fail"; exit 1; }
( assert_file /nonexistent-xyz ) && { echo "FAIL: assert_file did not fail"; exit 1; }
( assert_real_dir /etc/os-release ) && { echo "FAIL: assert_real_dir accepted a file"; exit 1; }
assert_eq a a "positive case"
assert_real_dir /etc
echo "harness selfcheck ok"
