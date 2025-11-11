# Project Structure Summary

## Completed Components

### ✅ Attacker Probes (`attacker/`)
- **common.h**: Shared utilities (RDTSC timing, CSV output, memory allocation)
- **cache_probe.c**: L1/L2/L3 cache contention probe using pointer-chasing
- **tlb_probe.c**: TLB contention probe with strided page accesses
- **btb_probe.c**: Branch Target Buffer probe using indirect branches
- **pht_probe.c**: Pattern History Table probe with varied branch patterns
- **Makefile**: Builds all probe binaries

All probes output CSV format: `ts_ns,probe,iter,cycles`

### ✅ Driver (`driver/`)
- **run_utils.py**: Run ID generation, logging, metadata, frequency sampling
- **driver.py**: Orchestrates victim + attacker, captures all outputs

### ✅ Victim Setup (`victim/`)
- **README.md**: Complete instructions for:
  - Installing llama.cpp
  - Downloading TinyLLaMA models
  - Running experiments with CPU pinning
  - Parameter sweep examples

### ✅ Analysis (`analysis/`)
- **analysis.py**: Full analysis pipeline:
  - Loads run data from logs
  - Computes statistics (mean, median, percentiles)
  - Generates visualizations (histograms, boxplots, PCA)
  - Trains classifiers (Random Forest) for fingerprinting
  - Outputs confusion matrices and feature importance

### ✅ Automation Scripts
- **setup.sh**: Quick start script (builds probes, checks dependencies, tests)
- **run_sweeps.sh**: Example sweep automation (S1, S2, S3)
- **requirements.txt**: Python dependencies

## Quick Start

1. **Build and verify setup:**
   ```bash
   ./setup.sh
   ```

2. **Install llama.cpp** (see `victim/README.md`)

3. **Run a single experiment:**
   ```bash
   python3 driver/driver.py \
     --victim-bin ~/llama.cpp/main \
     --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \
     --victim-cpu 2 --attacker-cpu 6 \
     --probe-bin ./attacker/cache_probe \
     --probe cache
   ```

4. **Run full parameter sweeps:**
   ```bash
   ./run_sweeps.sh
   ```

5. **Analyze results:**
   ```bash
   python3 analysis/analysis.py --logs-dir logs
   ```

## Directory Structure
```
microarch_finalproject/
├── README.md              # Project overview and specification
├── setup.sh              # Quick start script
├── run_sweeps.sh         # Automated parameter sweeps
├── requirements.txt      # Python dependencies
├── attacker/             # ✅ Complete
│   ├── common.h
│   ├── cache_probe.c
│   ├── tlb_probe.c
│   ├── btb_probe.c
│   ├── pht_probe.c
│   └── Makefile
├── driver/               # ✅ Complete
│   ├── driver.py
│   └── run_utils.py
├── victim/               # ✅ Complete
│   └── README.md
├── analysis/             # ✅ Complete
│   └── analysis.py
└── logs/                 # Created during runs
    ├── runs/
    │   └── <run_id>/
    │       ├── meta.json
    │       ├── probe.csv
    │       ├── freq.csv
    │       ├── victim_stdout.txt
    │       └── attacker_stdout.txt
    └── index.csv
```

## Key Features

### Probe Design
- **RDTSC-based timing**: Accurate cycle measurements
- **Warmup iterations**: Discards initial unstable measurements
- **CSV output**: Analysis-friendly format
- **Configurable iterations**: Flexible experiment duration

### Standardized Logging
- **Unique run IDs**: Time-sortable with encoded parameters
- **Complete metadata**: JSON format with all experimental parameters
- **Frequency sampling**: 20ms resolution CPU frequency tracking
- **Index CSV**: Easy querying across all runs

### Analysis Pipeline
- **Statistics**: Per-run mean, std, percentiles
- **Visualizations**: Distributions, PCA, confusion matrices
- **ML Classification**: Random Forest for fingerprinting
- **Reproducible**: Standardized figures and CSV outputs

## Next Steps

1. ✅ All core components implemented
2. 🔄 Install llama.cpp and download models
3. 🔄 Verify SMT topology (`grep . /sys/devices/system/cpu/cpu*/topology/thread_siblings_list`)
4. 🔄 Set CPU governor to performance (`sudo cpupower frequency-set -g performance`)
5. 🔄 Run pilot experiments to validate signal
6. 🔄 Execute full parameter sweeps
7. 🔄 Analyze results and generate figures for paper

## Testing

Probes tested and working:
```bash
$ ./attacker/cache_probe 0 10
ts_ns,probe,iter,cycles
3119594174147265,cache,0,490746
3119594174183837,cache,1,34498
...

$ ./attacker/btb_probe 0 10
ts_ns,probe,iter,cycles
3119603995163539,btb,0,3438
3119603995183137,btb,1,2100
...
```

All binaries compile without errors. Ready for experiments!
