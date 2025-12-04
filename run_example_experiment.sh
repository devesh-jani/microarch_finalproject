#!/bin/bash
# run_example_experiment.sh - Complete end-to-end experiment example
#
# This script demonstrates a full experiment run:
# 1. Builds probes (if needed)
# 2. Checks victim setup
# 3. Runs a single experiment with cache_probe
# 4. Shows the output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Example SMT Contention Experiment ==="
echo

# Configuration
LLAMA_BIN="${HOME}/llama.cpp/build/bin/llama-cli"
MODEL_PATH="${HOME}/llama.cpp/models/tinyllama-1.1b-q4_0.gguf"
VICTIM_CPU=0
ATTACKER_CPU=56  # Adjust based on your SMT topology

# Check if probes are built
echo "1. Checking attacker probes..."
if [ ! -f "attacker/cache_probe" ]; then
    echo "   Building probes..."
    cd attacker && make && cd ..
fi
echo "   ✓ Probes ready"

# Check victim setup
echo
echo "2. Checking victim (llama.cpp) setup..."
if [ ! -f "$LLAMA_BIN" ]; then
    echo "   ⚠  llama.cpp not found at: $LLAMA_BIN"
    echo "   Run: ./setup_victim.sh"
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "   ⚠  TinyLLaMA model not found at: $MODEL_PATH"
    echo "   Run: ./setup_victim.sh"
    exit 1
fi
echo "   ✓ Victim ready"

# Check SMT topology
echo
echo "3. Checking SMT topology..."
if [ -f "/sys/devices/system/cpu/cpu${VICTIM_CPU}/topology/thread_siblings_list" ]; then
    SIBLINGS=$(cat /sys/devices/system/cpu/cpu${VICTIM_CPU}/topology/thread_siblings_list)
    echo "   CPU ${VICTIM_CPU} siblings: ${SIBLINGS}"
    
    # Verify attacker CPU is a sibling
    if [[ ! "$SIBLINGS" =~ (^|,)${ATTACKER_CPU}(,|$) ]]; then
        echo "   ⚠  WARNING: CPU ${ATTACKER_CPU} is NOT a sibling of CPU ${VICTIM_CPU}"
        echo "   Siblings should share the same physical core"
        echo "   Continue anyway? (y/N): "
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "   ✓ SMT sibling pair confirmed"
    fi
else
    echo "   ⚠  Cannot verify SMT topology"
fi

# Check CPU governor
echo
echo "4. Checking CPU configuration..."
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
echo "   CPU Governor: ${GOVERNOR}"
if [ "$GOVERNOR" != "performance" ]; then
    echo "   ⚠  Recommended: 'performance' governor for consistent results"
    echo "   Set with: sudo cpupower frequency-set -g performance"
fi

# Run experiment
echo
echo "5. Running experiment..."
echo "   Victim: CPU ${VICTIM_CPU}, TinyLLaMA Q4_0, ctx=512, n=64"
echo "   Attacker: CPU ${ATTACKER_CPU}, cache_probe, 1000 iterations"
echo

python3 driver/driver.py \
    --root . \
    --victim-bin "$LLAMA_BIN" \
    --model "$MODEL_PATH" \
    --quant q4_0 \
    --ctx 512 \
    --npredict 64 \
    --decoding greedy \
    --prompt "Explain caching with an example." \
    --seed 42 \
    --repeat 1 \
    --victim-cpu $VICTIM_CPU \
    --attacker-cpu $ATTACKER_CPU \
    --probe-bin ./attacker/cache_probe \
    --probe cache \
    --iters 1000 \
    --warmup-ms 200

echo
echo "=== Experiment Complete ==="
echo

# Find the latest run
LATEST_RUN=$(ls -td logs/runs/*/ 2>/dev/null | head -1)

if [ -n "$LATEST_RUN" ]; then
    echo "Results saved to: $LATEST_RUN"
    echo
    echo "Quick summary of probe measurements:"
    echo "----------------------------------------"
    
    # Show CSV header and first 10 data rows
    if [ -f "${LATEST_RUN}/probe.csv" ]; then
        echo "First 10 probe measurements:"
        head -11 "${LATEST_RUN}/probe.csv"
        echo "..."
        
        # Show basic statistics
        if command -v python3 &>/dev/null; then
            echo
            echo "Statistics:"
            python3 -c "
import pandas as pd
import sys
df = pd.read_csv('${LATEST_RUN}/probe.csv')
print(f'  Total measurements: {len(df)}')
print(f'  Mean cycles: {df[\"cycles\"].mean():.0f}')
print(f'  Median cycles: {df[\"cycles\"].median():.0f}')
print(f'  Std dev: {df[\"cycles\"].std():.0f}')
print(f'  Min: {df[\"cycles\"].min()}')
print(f'  Max: {df[\"cycles\"].max()}')
print(f'  P90: {df[\"cycles\"].quantile(0.9):.0f}')
print(f'  P99: {df[\"cycles\"].quantile(0.99):.0f}')
"
        fi
    fi
    
    echo
    echo "Metadata:"
    if [ -f "${LATEST_RUN}/meta.json" ]; then
        cat "${LATEST_RUN}/meta.json" | head -20
    fi
    
    echo
    echo "----------------------------------------"
    echo "Next steps:"
    echo "  1. Run more experiments with different parameters"
    echo "  2. Collect multiple repeats (--repeat 1, 2, 3, ...)"
    echo "  3. Analyze with: python3 analysis/analysis.py"
fi
