# Getting Started - Quick Reference

This guide helps you get started quickly with the SMT contention experiments.

## Prerequisites

- Intel x86 CPU with SMT (Hyper-Threading) enabled
- Linux operating system
- gcc, make, python3
- Sudo access for performance tuning (optional but recommended)

## Step-by-Step Setup

### 1. Build the Attacker Probes

```bash
cd attacker
make
```

This creates: `cache_probe`, `tlb_probe`, `btb_probe`, `pht_probe`

### 2. Install Python Dependencies

```bash
pip3 install -r requirements.txt
```

Or if you prefer virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Install and Setup llama.cpp

Follow the detailed instructions in `victim/README.md`:

```bash
# Clone and build
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
make

# Download TinyLLaMA model
mkdir -p models
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf \
  -O models/tinyllama-1.1b-q4_0.gguf
```

### 4. Check Your CPU Topology

Find SMT sibling pairs:
```bash
grep . /sys/devices/system/cpu/cpu*/topology/thread_siblings_list
```

Example output:
```
/sys/devices/system/cpu/cpu0/topology/thread_siblings_list:0,4
/sys/devices/system/cpu/cpu2/topology/thread_siblings_list:2,6
```

**Important:** CPUs 2 and 6 are SMT siblings. Use these for victim and attacker.

### 5. Optimize System for Experiments (Recommended)

```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Verify
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

## Running Your First Experiment

### Quick Test

Test all probes individually:
```bash
./test_probes.sh
```

### Single Experiment Run

```bash
python3 driver/driver.py \
  --victim-bin ~/llama.cpp/main \
  --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
  --quant q4_0 \
  --ctx 512 \
  --npredict 64 \
  --victim-cpu 2 \
  --attacker-cpu 6 \
  --probe-bin ./attacker/cache_probe \
  --probe cache \
  --repeat 1
```

**Adjust CPU numbers** based on your system's SMT topology!

### Check the Results

Results are saved in `logs/runs/<run_id>/`:
```bash
ls -lh logs/runs/
cat logs/runs/*/meta.json | head -20
```

## Running Full Parameter Sweeps

Edit `run_sweeps.sh` to match your system configuration:
```bash
# Update these variables in run_sweeps.sh
VICTIM_BIN="$HOME/llama.cpp/main"
MODEL_DIR="$HOME/llama.cpp/models"
VICTIM_CPU=2        # Update based on your topology
ATTACKER_CPU=6      # Update based on your topology
```

Then run:
```bash
./run_sweeps.sh
```

**Warning:** Full sweeps can take hours. Start with a small subset first.

## Analyzing Results

Once you have collected some runs:

```bash
python3 analysis/analysis.py --logs-dir logs --output-dir analysis/figs
```

This generates:
- `analysis/figs/hist_*.png` - Cycle distributions
- `analysis/figs/boxplot_*.png` - Comparison plots
- `analysis/figs/pca_runs.png` - PCA visualization
- `analysis/figs/confusion_*.png` - Classification results
- `analysis/figs/run_statistics.csv` - Summary statistics

## Troubleshooting

### No Signal / Flat Data

**Problem:** All cycles measurements are similar regardless of victim activity

**Solutions:**
1. Verify SMT siblings: victim and attacker must be on the same physical core
2. Increase probe iterations: `--iters 5000`
3. Increase victim workload: `--ctx 2048 --npredict 256`
4. Check that victim is actually running during probe execution

### High Noise / Variance

**Problem:** Measurements have high variance

**Solutions:**
1. Set CPU governor to performance
2. Close background applications
3. Increase number of repeats: `--repeat 5`
4. Use CPU isolation (advanced): add `isolcpus=2,6` to kernel boot parameters

### Victim Not Running

**Problem:** `driver.py` reports victim errors

**Solutions:**
1. Check that llama.cpp binary exists and is executable
2. Test victim manually: `~/llama.cpp/main -m <model> -t 1 -c 512 -n 64 -p "Test"`
3. Verify model file exists and is complete
4. Check `logs/runs/*/victim_stdout.txt` for error messages

### Import Errors in Python

**Problem:** `ModuleNotFoundError: No module named 'pandas'`

**Solutions:**
```bash
pip3 install -r requirements.txt
# Or
pip3 install pandas numpy matplotlib seaborn scikit-learn
```

### Permission Denied for Frequency Sampling

**Problem:** Cannot read `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`

**Solutions:**
- Frequency sampling will log `-1` and continue (non-critical)
- Or run with elevated permissions (not recommended for experiments)

## File Organization

After running experiments:
```
logs/
├── index.csv                    # Index of all runs
└── runs/
    └── <run_id>/
        ├── meta.json            # Full metadata
        ├── probe.csv            # Probe measurements
        ├── freq.csv             # CPU frequency samples
        ├── victim_stdout.txt    # Victim output
        └── attacker_stdout.txt  # Probe output
```

## Baseline Experiments

For comparison, run these controls:

1. **Probe only (no victim):**
   ```bash
   ./attacker/cache_probe 2 2000 > probe_only.csv
   ```

2. **Victim only (no attacker):**
   ```bash
   taskset -c 2 ~/llama.cpp/main -m ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf -t 1 -c 512 -n 64
   ```

3. **Different physical cores (no SMT contention):**
   ```bash
   # Use CPUs on different physical cores, e.g., CPU 0 and CPU 2
   python3 driver/driver.py ... --victim-cpu 0 --attacker-cpu 2
   ```

## Next Steps

1. ✅ Complete setup and verify all probes work
2. Run pilot experiments with 3-5 repeats per condition
3. Analyze pilot data to verify signal quality
4. Run full parameter sweeps (S1, S2, S3)
5. Generate visualizations and statistics
6. Train classifiers for fingerprinting
7. Document findings in paper

## Need Help?

- Check the main `README.md` for detailed specifications
- Review `PROJECT_STATUS.md` for implementation status
- See `victim/README.md` for llama.cpp setup details
- Examine example scripts: `test_probes.sh`, `run_sweeps.sh`

## Quick Reference Commands

```bash
# Build probes
cd attacker && make

# Test probes
./test_probes.sh

# Single run
python3 driver/driver.py --victim-bin ~/llama.cpp/main --model <model> \
  --victim-cpu 2 --attacker-cpu 6 --probe-bin ./attacker/cache_probe --probe cache

# Full sweeps
./run_sweeps.sh

# Analyze
python3 analysis/analysis.py

# Check SMT topology
grep . /sys/devices/system/cpu/cpu*/topology/thread_siblings_list

# Set performance mode
sudo cpupower frequency-set -g performance
```
