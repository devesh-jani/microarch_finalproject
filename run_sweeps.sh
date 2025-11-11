#!/bin/bash
# Example sweep script demonstrating parameter sweeps for SMT contention experiments

set -e

# Configuration
PROJECT_ROOT="/mnt/ncsudrive/d/dhjani2/microarch_finalproject"
VICTIM_BIN="$HOME/llama.cpp/main"
MODEL_DIR="$HOME/llama.cpp/models"
VICTIM_CPU=2
ATTACKER_CPU=6  # Must be SMT sibling of VICTIM_CPU

# Check if victim binary exists
if [ ! -f "$VICTIM_BIN" ]; then
    echo "Error: llama.cpp not found at $VICTIM_BIN"
    echo "Please install llama.cpp first (see victim/README.md)"
    exit 1
fi

cd "$PROJECT_ROOT"

# S1: Working Set / Context Sweep
echo "=== S1: Working Set / Context Sweep ==="
echo "Testing cache and TLB probes with varying context sizes..."

for ctx in 128 512 2048; do
    for npredict in 16 64 256; do
        for repeat in 1 2 3; do
            echo "Running: ctx=$ctx, npredict=$npredict, repeat=$repeat (cache)"
            python3 driver/driver.py \
                --root . \
                --victim-bin "$VICTIM_BIN" \
                --model "$MODEL_DIR/tinyllama-1.1b-q4_0.gguf" \
                --quant q4_0 \
                --ctx $ctx \
                --npredict $npredict \
                --decoding greedy \
                --victim-cpu $VICTIM_CPU \
                --attacker-cpu $ATTACKER_CPU \
                --probe-bin ./attacker/cache_probe \
                --probe cache \
                --iters 2000 \
                --repeat $repeat || echo "Run failed, continuing..."
            
            sleep 2  # Cool-down between runs
        done
    done
done

# S2: Quantization Width Sweep
echo
echo "=== S2: Quantization Width Sweep ==="
echo "Testing different quantization levels..."

for quant in q4_0 q5_0 q8_0; do
    model_file="$MODEL_DIR/tinyllama-1.1b-$quant.gguf"
    
    if [ ! -f "$model_file" ]; then
        echo "Warning: Model $model_file not found, skipping..."
        continue
    fi
    
    for repeat in 1 2 3; do
        for probe_name in cache tlb; do
            echo "Running: quant=$quant, repeat=$repeat, probe=$probe_name"
            python3 driver/driver.py \
                --root . \
                --victim-bin "$VICTIM_BIN" \
                --model "$model_file" \
                --quant $quant \
                --ctx 512 \
                --npredict 64 \
                --decoding greedy \
                --victim-cpu $VICTIM_CPU \
                --attacker-cpu $ATTACKER_CPU \
                --probe-bin ./attacker/${probe_name}_probe \
                --probe $probe_name \
                --iters 2000 \
                --repeat $repeat || echo "Run failed, continuing..."
            
            sleep 2
        done
    done
done

# S3: Access Pattern / Decoding Sweep
echo
echo "=== S3: Access Pattern / Decoding Sweep ==="
echo "Testing greedy vs sampling decoding with branch predictor probes..."

for decoding in greedy sample; do
    for repeat in 1 2 3; do
        for probe_name in btb pht; do
            echo "Running: decoding=$decoding, repeat=$repeat, probe=$probe_name"
            
            if [ "$decoding" == "greedy" ]; then
                python3 driver/driver.py \
                    --root . \
                    --victim-bin "$VICTIM_BIN" \
                    --model "$MODEL_DIR/tinyllama-1.1b-q4_0.gguf" \
                    --quant q4_0 \
                    --ctx 512 \
                    --npredict 64 \
                    --decoding greedy \
                    --victim-cpu $VICTIM_CPU \
                    --attacker-cpu $ATTACKER_CPU \
                    --probe-bin ./attacker/${probe_name}_probe \
                    --probe $probe_name \
                    --iters 2000 \
                    --repeat $repeat || echo "Run failed, continuing..."
            else
                python3 driver/driver.py \
                    --root . \
                    --victim-bin "$VICTIM_BIN" \
                    --model "$MODEL_DIR/tinyllama-1.1b-q4_0.gguf" \
                    --quant q4_0 \
                    --ctx 512 \
                    --npredict 64 \
                    --decoding sample \
                    --temp 1.0 \
                    --top-k 40 \
                    --top-p 0.95 \
                    --victim-cpu $VICTIM_CPU \
                    --attacker-cpu $ATTACKER_CPU \
                    --probe-bin ./attacker/${probe_name}_probe \
                    --probe $probe_name \
                    --iters 2000 \
                    --repeat $repeat || echo "Run failed, continuing..."
            fi
            
            sleep 2
        done
    done
done

echo
echo "=== All sweeps complete! ==="
echo "Run analysis with: python3 analysis/analysis.py --logs-dir logs"
