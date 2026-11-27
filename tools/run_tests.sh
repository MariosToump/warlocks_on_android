#!/bin/bash
# Full Godot test suite:  bash tools/run_tests.sh
# Windowed tests (need a display): test_touch, test_shop_layout. test_sim runs at --fixed-fps 60.
cd "$(dirname "$0")/.."
G="${GODOT:-D:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
fail=0; n=0
for f in tools/test_*.gd; do
  b=$(basename $f .gd); n=$((n+1))
  if [ "$b" = test_touch ] || [ "$b" = test_shop_layout ]; then h=""; else h="--headless"; fi
  [ "$b" = test_sim ] && h="--headless --fixed-fps 60"
  out=$(timeout 300 "$G" $h --path . -s $f 2>&1)
  if echo "$out" | grep -q "TEST PASSED"; then echo "ok   $b"; else echo "FAIL $b"; echo "$out" | grep -E "FAIL|ERROR" | head -5; fail=$((fail+1)); fi
done
python -I tools/sim/test_analyze.py >/dev/null 2>&1 && echo "ok   test_analyze (python)" || { echo "FAIL test_analyze (python)"; fail=$((fail+1)); }
n=$((n+1))
echo "suite: $((n-fail))/$n passed"
[ $fail -eq 0 ]
