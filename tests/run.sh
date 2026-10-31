#!/bin/sh
# Pulse gate: every test file native, then --target=js.
MSC=${MSC:-msc}
cd "$(dirname "$0")/.."
files=$(find tests -name "*.test.ms" | sort)
fail=0
for f in $files; do
	echo "== native $f"
	"$MSC" test "$f" || fail=1
done
for f in $files; do
	echo "== js $f"
	"$MSC" test --target=js "$f" || fail=1
done
exit $fail
