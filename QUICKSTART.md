# Quick Start Guide

This guide will get you from zero to running your first SMT contention experiment in minutes.

## Prerequisites

- Linux system with Intel CPU (SMT/Hyper-Threading enabled)
- gcc, make, git, wget
- Python 3.8+ with pip
- At least 2GB free disk space for models

## Step-by-Step Setup

### 1. Build Attacker Probes

```bash
cd /mnt/ncsudrive/d/dhjani2/microarch_finalproject
./setup.sh
```

This will:
- Compile all probe binaries (cache, TLB, BTB, PHT)
- Check Python dependencies
- Verify CPU configuration
- Test a probe

### 2. Install Python Dependencies

```bash
pip3 install -r requirements.txt
```

Or if you prefer a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Setup Victim (TinyLLaMA)

```bash
./setup_victim.sh
```

This will:
- Clone and build llama.cpp
- Download TinyLLaMA Q4_0 model (~600MB)
- Optionally download Q5_0 and Q8_0 models
- Test the installation

**Note:** Download will take a few minutes depending on your connection.

### 4. Find Your SMT Siblings

```bash
# List all SMT sibling pairs
grep . /sys/devices/system/cpu/cpu*/topology/thread_siblings_list

# Example output:
# cpu0/topology/thread_siblings_list:0,4  <- CPUs 0 and 4 are siblings
# cpu1/topology/thread_siblings_list:1,5  <- CPUs 1 and 5 are siblings
# cpu2/topology/thread_siblings_list:2,6  <- CPUs 2 and 6 are siblings
# cpu3/topology/thread_siblings_list:3,7  <- CPUs 3 and 7 are siblings
```

**Choose a sibling pair for your experiments.** For example, if you pick CPUs 2 and 6:
- Victim runs on CPU 2
- Attacker probe runs on CPU 6

### 5. Run Your First Experiment

**Option A: Automated Example**

```bash
# Edit run_example_experiment.sh to set your CPU pair
nano run_example_experiment.sh
# Change VICTIM_CPU and ATTACKER_CPU based on step 4

# Run the example
./run_example_experiment.sh
```

**Option B: Manual Run**

```bash
python3 driver/driver.py \
  --victim-bin ~/llama.cpp/main \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --victim-cpu 2 \
  --attacker-cpu 6 \
  --probe-bin ./attacker/cache_probe \
  --probe cache \
  --ctx 512 \
  --npredict 64 \
  --repeat 1
```

### 6. Check Results

Results are saved in `logs/runs/<run_id>/`:

```bash
# List all runs
ls -lt logs/runs/

# View the latest run
LATEST=$(ls -t logs/runs/ | head -1)
echo "Latest run: $LATEST"

# View probe measurements
head logs/runs/$LATEST/probe.csv

# View metadata
cat logs/runs/$LATEST/meta.json

# View frequency trace
head logs/runs/$LATEST/freq.csv
```

### 7. Run Analysis

After collecting several experiments:

```bash
python3 analysis/analysis.py --logs-dir logs --output-dir analysis/figs

# View generated figures
ls -lh analysis/figs/
```

## Recommended First Experiments

### Experiment 1: Baseline Measurements

Collect baseline data with different probes:

```bash
# Cache probe
python3 driver/driver.py --victim-bin ~/llama.cpp/build/bin/llama-cli \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --victim-cpu 2 --attacker-cpu 6 \
  --probe-bin ./attacker/cache_probe --probe cache --repeat 1

# TLB probe
python3 driver/driver.py --victim-bin ~/llama.cpp/build/bin/llama-cli \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --victim-cpu 2 --attacker-cpu 6 \
  --probe-bin ./attacker/tlb_probe --probe tlb --repeat 1

# BTB probe
python3 driver/driver.py --victim-bin ~/llama.cpp/build/bin/llama-cli \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --victim-cpu 2 --attacker-cpu 6 \
  --probe-bin ./attacker/btb_probe --probe btb --repeat 1
```

### Experiment 2: Context Size Sweep

Test how working set size affects contention:

```bash
# Small context (128 tokens)
python3 driver/driver.py [...] --ctx 128 --npredict 16 --repeat 1

# Medium context (512 tokens)
python3 driver/driver.py [...] --ctx 512 --npredict 64 --repeat 2

# Large context (2048 tokens)
python3 driver/driver.py [...] --ctx 2048 --npredict 256 --repeat 3
```

### Experiment 3: Quantization Sweep

Compare different quantization levels (if you downloaded multiple models):

```bash
# Q4_0 (4-bit)
python3 driver/driver.py [...] --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf --quant q4_0

# Q5_0 (5-bit)
python3 driver/driver.py [...] --model ~/llama.cpp/models/tinyllama-1.1b-q5_0.gguf --quant q5_0

# Q8_0 (8-bit)
python3 driver/driver.py [...] --model ~/llama.cpp/models/tinyllama-1.1b-q8_0.gguf --quant q8_0
```

## Troubleshooting

### "llama.cpp not found"
```bash
./setup_victim.sh
```

### "Model not found"
```bash
# Check if model exists
ls -lh ~/llama.cpp/models/

# Re-download if needed
cd ~/llama.cpp/models
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf \
  -O tinyllama-1.1b-q4_0.gguf
```

### "Python package not found"
```bash
pip3 install -r requirements.txt
```

### "No signal / flat data"
- Ensure victim and attacker are on SMT siblings (same physical core)
- Increase probe iterations: `--iters 5000`
- Increase victim workload: `--ctx 2048 --npredict 256`

### "High noise"
```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Close unnecessary applications
# Disable turbo boost (optional, for consistency):
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```

## Performance Tips

### For Consistent Results:

1. **Set CPU governor:**
   ```bash
   sudo cpupower frequency-set -g performance
   ```

2. **Run multiple repeats:**
   ```bash
   # Repeat the same experiment 3 times
   python3 driver/driver.py [...] --repeat 1
   python3 driver/driver.py [...] --repeat 2
   python3 driver/driver.py [...] --repeat 3
   ```

3. **Use longer runs:**
   ```bash
   python3 driver/driver.py [...] --iters 5000
   ```

4. **Discard warmup:**
   The analysis script discards the first 500 iterations by default.

## Next Steps

1. **Collect systematic data:** Run the recommended experiment sweeps (S1, S2, S3 from README.md)
2. **Analyze results:** Use `analysis/analysis.py` to generate visualizations and train classifiers
3. **Write up findings:** Document your observations in `paper/`
4. **Compare with baselines:** Run experiments with victim-only, probe-only, and no-SMT configurations

## Quick Reference

```bash
# Build probes
cd attacker && make

# Setup victim
./setup_victim.sh

# Run experiment
python3 driver/driver.py --victim-bin ~/llama.cpp/build/bin/llama-cli \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --victim-cpu 2 --attacker-cpu 6 \
  --probe-bin ./attacker/cache_probe --probe cache

# Analyze
python3 analysis/analysis.py

# View results
ls logs/runs/
```

## Documentation

- Full README: `README.md`
- Victim setup: `victim/README.md`
- Attacker probes: `attacker/*.c`
- Driver documentation: `driver/driver.py --help`
- Analysis options: `python3 analysis/analysis.py --help`
