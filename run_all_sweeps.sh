#!/bin/bash
# Automated sweep script for SMT contention experiments
# Runs all recommended parameter combinations

set -e

VICTIM_BIN="${HOME}/llama.cpp/build/bin/llama-cli"
MODEL_Q4="${HOME}/llama.cpp/models/tinyllama-1.1b-q4_0.gguf"
VICTIM_CPU=0
ATTACKER_CPU=56

echo "=== Starting Automated Sweeps ==="
echo "Victim CPU: $VICTIM_CPU"
echo "Attacker CPU: $ATTACKER_CPU"
echo

# Check if model exists
if [ ! -f "$MODEL_Q4" ]; then
    echo "Error: Q4 model not found at $MODEL_Q4"
    exit 1
fi

# Sweep 1: Context Size (with cache and TLB probes)
echo "=== Sweep 1: Context Size / Working Set ==="
for ctx in 128 512 2048; do
    for npredict in 16 64 256; do
        for probe in cache tlb; do
            for repeat in 1 2 3; do
                echo "Running: ctx=$ctx, npredict=$npredict, probe=$probe, repeat=$repeat"
                python3 driver/driver.py \
                    --victim-bin "$VICTIM_BIN" \
                    --model "$MODEL_Q4" \
                    --victim-cpu $VICTIM_CPU \
                    --attacker-cpu $ATTACKER_CPU \
                    --probe-bin "./attacker/${probe}_probe" \
                    --probe "$probe" \
                    --ctx $ctx \
                    --npredict $npredict \
                    --repeat $repeat \
                    --quant q4_0 || echo "Failed: ctx=$ctx, n=$npredict, probe=$probe, r=$repeat"
                
                # Small delay between runs
                sleep 2
            done
        done
    done
done

echo
echo "=== Sweep 1 Complete ==="
echo

# Sweep 3: Access Pattern (greedy vs sampling)
echo "=== Sweep 3: Access Pattern / Decoding Strategy ==="
for probe in btb pht; do
    for repeat in 1 2 3; do
        # Greedy decoding
        echo "Running: greedy decoding, probe=$probe, repeat=$repeat"
        python3 driver/driver.py \
            --victim-bin "$VICTIM_BIN" \
            --model "$MODEL_Q4" \
            --victim-cpu $VICTIM_CPU \
            --attacker-cpu $ATTACKER_CPU \
            --probe-bin "./attacker/${probe}_probe" \
            --probe "$probe" \
            --ctx 512 \
            --npredict 64 \
            --decoding greedy \
            --repeat $repeat \
            --quant q4_0 || echo "Failed: greedy, probe=$probe, r=$repeat"
        
        sleep 2
        
        # Sampling decoding
        echo "Running: sampling decoding, probe=$probe, repeat=$repeat"
        python3 driver/driver.py \
            --victim-bin "$VICTIM_BIN" \
            --model "$MODEL_Q4" \
            --victim-cpu $VICTIM_CPU \
            --attacker-cpu $ATTACKER_CPU \
            --probe-bin "./attacker/${probe}_probe" \
            --probe "$probe" \
            --ctx 512 \
            --npredict 64 \
            --decoding sample \
            --temp 1.0 \
            --top-k 40 \
            --top-p 0.95 \
            --repeat $repeat \
            --quant q4_0 || echo "Failed: sampling, probe=$probe, r=$repeat"
        
        sleep 2
    done
done

echo
echo "=== Sweep 3 Complete ==="
echo

# Summary
echo "=== All Sweeps Complete! ==="
echo
echo "Total runs collected:"
ls -1 logs/runs/ | wc -l
echo
echo "Next steps:"
echo "  1. Check results: ls -lt logs/runs/"
echo "  2. Run analysis: python3 analysis/analysis.py"
echo
echo "Note: Sweep 2 (quantization) requires Q5_0 and Q8_0 models."
echo "      Download them and add to this script if needed."
