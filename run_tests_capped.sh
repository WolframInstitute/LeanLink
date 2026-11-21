#!/usr/bin/env bash
# Run LeanLink's test files on a machine that allows Wolfram only small runs: each file whole in a fresh kernel under a
# memory cap and a time limit, and a file that passes neither in one test at a time, each test in a fresh kernel under the
# same cap (run_test_isolated.wls). A test the cap stops is reported as not run, with the cap that stopped it, never as a
# failure. Each run starts only at memory pressure 1. The results go to <out>/results.tsv: file, test (or "*" for the
# whole file), outcome, seconds, peak GB.
#
#     ./run_tests_capped.sh --memcap path/to/memcap.py [--cap-gb 2] [--timeout 120] [--out dir] [File.wlt ...]
#
# memcap.py is the shared machine's watchdog (KernelCompiler/Scripts/memcap.py): it caps the physical footprint of the
# kernel's whole process tree and writes a JSON report. With no files, every file in LeanLink/Tests.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
CAP=2
TIMEOUT=120
OUT="$ROOT/test-results"
MEMCAP=""
FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --memcap) MEMCAP="$2"; shift 2 ;;
        --cap-gb) CAP="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        *) FILES+=("$1"); shift ;;
    esac
done
[ -n "$MEMCAP" ] || { echo "--memcap path/to/memcap.py is required"; exit 1; }
[ ${#FILES[@]} -gt 0 ] || while IFS= read -r f; do FILES+=("$(basename "$f")"); done < <(ls "$ROOT"/LeanLink/Tests/*.wlt)
mkdir -p "$OUT"
RESULTS="$OUT/results.tsv"
printf 'file\ttest\toutcome\tseconds\tpeak_gb\n' > "$RESULTS"

wait_quiet() { until [ "$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 1)" -le 1 ]; do sleep 30; done; }

# capped name log -- command...: runs it under the cap; prints "<outcome> <seconds> <peak GB>" from memcap's report
capped() {
    local name="$1" log="$2"; shift 2
    wait_quiet
    nice -n 19 python3 -I "$MEMCAP" --cap-gb "$CAP" --timeout "$TIMEOUT" --report "$OUT/$name.json" -- "$@" > "$log" 2>&1
    python3 -I -c "
import json, sys
r = json.load(open(sys.argv[1]))
killed = r.get('killed')
outcome = 'NotRun-' + killed if killed in ('memory', 'time') else ('Success' if r.get('exit') == 0 else 'Failure')
print(outcome, round(r.get('seconds', 0), 1), round(r.get('peak', 0) / 2**30, 2))" "$OUT/$name.json"
}

for file in "${FILES[@]}"; do
    stem="${file%.wlt}"
    read -r outcome seconds peak < <(capped "$stem" "$OUT/$stem.log" wolframscript -file "$ROOT/run_tests.wls" "$file")
    # run_tests.wls exits 0 only when every test of the file passed
    printf '%s\t*\t%s\t%s\t%s\n' "$file" "$outcome" "$seconds" "$peak" >> "$RESULTS"
    echo "$file whole: $outcome ($seconds s, $peak GB)"
    [ "$outcome" = "Success" ] && continue
    # the file whole did not pass: each of its tests alone, in a fresh kernel
    wolframscript -file "$ROOT/run_test_isolated.wls" "$file" --list > "$OUT/$stem.ids" 2>/dev/null
    index=0
    while IFS= read -r id; do
        index=$((index + 1))
        read -r outcome seconds peak < <(capped "$stem-$index" "$OUT/$stem-$index.log" wolframscript -file "$ROOT/run_test_isolated.wls" "$file" "$id")
        printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$id" "$outcome" "$seconds" "$peak" >> "$RESULTS"
        echo "  $id: $outcome ($seconds s, $peak GB)"
    done < "$OUT/$stem.ids"
done
echo "results: $RESULTS"
