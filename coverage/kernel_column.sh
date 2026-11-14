#!/bin/zsh
# kernel_column.sh - each test file in a kernel process of its own, as rows for coverage/kernels.md:
# the kernel's $Version, the file, passed/total, seconds and peak memory.
#
#     coverage/kernel_column.sh "wolframscript -file" [File.wlt ...]
#     coverage/kernel_column.sh "$HOME/Library/Wolfram/ApplicationData/WolframKernel/bin/wl -f" [File.wlt ...]
#
# The first argument starts a kernel on a script. The files default to those that fit 2 GB.
# MEMCAP, when set, is a command put before each run to cap its memory, as
# "python3 -I .../memcap.py --cap-gb 2 --timeout 600 --"; a run it kills is reported as killed.
# The peak is the kernel's own, from /usr/bin/time -l (macOS), or memcap's for the process tree.
root=${0:A:h:h}
kernel=(${=1}); shift
files=("$@"); [ ${#files} -eq 0 ] && files=(TypeTheoryBridge.wlt EvaluationStartup.wlt EvaluationTransport.wlt)
cap=(${=MEMCAP:-})
log=$(mktemp)
for file in $files; do
    start=$(date +%s)
    $cap /usr/bin/time -l $kernel $root/run_tests.wls $file > $log 2>&1
    seconds=$(( $(date +%s) - start ))
    version=$(grep -m1 "^Kernel: " $log | sed 's/^Kernel:  *//')
    passed=$(grep -m1 -oE "[0-9]+/[0-9]+ passed" $log | sed 's/ passed//')
    peak=$(grep -oE "peak footprint [0-9.]+ GB" $log | tail -1 | sed 's/peak footprint //')
    [ -z "$peak" ] && peak=$(awk '/peak memory footprint/ {printf "%.2f GB", $1 / 2^30}' $log)
    grep -q "memcap: .*exit 137\|memcap: killing" $log && passed="killed"
    echo "| ${version:-?} | $file | ${passed:-no result} | $seconds s | $peak |"
    grep -E "^    [^ ].*: (Failure|MessagesFailure|Error)" $log | sed 's/^    /    failed: /'
done
rm -f $log
