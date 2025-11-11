Project: Microarchitectural Characterization of SMT Contention Channels using TinyLLaMA
Goal: Measure how variations in TinyLLaMA inference (working-set, model width/quant, access pattern) produce observable contention across shared core microarchitectural structures (cache, TLB, ROB/register file, BTB/PHT) when an attacker probe runs on the SMT sibling.

Contents
README.md                <- you are reading
attacker/                <- microbench probes & Makefile
  ├─ common.h
  ├─ btb_probe.c
  ├─ pht_probe.c
  ├─ tlb_probe.c
  ├─ cache_probe.c
  ├─ rob_probe.c  (optional)
  └─ Makefile
victim/                  <- tinyllama/llama.cpp wrapper or run instructions
driver/                  <- sweep automation scripts
analysis/                <- analysis.py / analysis.ipynb
logs/                    <- run logs (csv + perf + meta)
env_metadata.json        <- recorded system metadata
paper/                   <- drafts, figures

Quick summary / TL;DR

Use TinyLLaMA (llama.cpp) as the victim inference workload pinned to one logical CPU.

Run an attacker probe (cache/tlb/btb/pht/rob probes) pinned to the SMT sibling.

Sweep TinyLLaMA parameters:

Working set: context size / tokens (-c 128,512,2048; -n-predict 16,64,256)

Model width/compute proxy: quantization (q4_0, q5_0, q8_0) — or alternate checkpoint widths if available

Access pattern / sparsity: deterministic (greedy) vs sampling; low-diversity vs high-diversity prompts

Collect per-iteration cycles, perf counters, and core frequency traces. Analyze with analysis/analysis.py.

Requirements / Environment

Machine: Intel x86 CPU with SMT enabled and TurboBoost enabled.

OS: Recent Linux (Ubuntu / Debian recommended).

Tools:

gcc (for probes), make

python3 (≥3.8) + pip packages: pandas, numpy, matplotlib, scikit-learn

perf (Linux perf_event)

llama.cpp (build for TinyLLaMA inference; or local TinyLLaMA binary)

Privileges: sudo required for some perf events or MSR access (optional).

Recommended: set CPU governor to performance during experiments:

sudo cpupower frequency-set -g performance

Setup instructions
1. Prepare attacker probes
cd attacker
make


This produces binaries: btb_probe, pht_probe, tlb_probe, cache_probe, (and optional) rob_probe.

Each probe prints a CSV to the current directory (e.g., cache_probe.csv).

2. Prepare TinyLLaMA victim

Build llama.cpp according to its README and place a quantized TinyLLaMA model file (e.g., tinyllama-1.1b-q4_0.gguf) in models/.

Example invocation (pin to CPU 2):

taskset -c 2 ./main -m models/tinyllama-1.1b-q4_0.gguf -c 512 -n-predict 64 --temp 0 -p "Explain caching with an example." -t 1


Notes:

-t 1 ensures single-threaded victim.

Adjust -c, -n-predict, quantized model filename per sweep.

3. Run attacker probe (SMT sibling)

Pin attacker to SMT sibling logical CPU (example CPU 3):

taskset -c 3 ./cache_probe 3   # run chosen probe

Recommended Sweep Matrix (TinyLLaMA-only)

Run each combination with ≥3 repeats for variance estimation.

S1: Working-set / Context

-c ∈ {128, 512, 2048}

-n-predict ∈ {16, 64, 256}

quant: q4_0 (fix for this sweep)

probes: cache_probe, tlb_probe

S2: Width / Compute proxy (quant)

quant files ∈ {q4_0, q5_0, q8_0} (or replace q* with different n_embd models if available)

-c 512, -n-predict 64, greedy

probes: rob_probe / regfile_probe, collect uops/resource_stalls via perf

S3: Access pattern / Sparsity

decode mode: greedy (--temp 0) vs sampling (--temp 1.0 --top-k 40 --top-p 0.95)

prompt diversity: low-diversity (repeated tokens) vs high-diversity (random tokens)

-c 512, -n-predict 64

probes: btb_probe, pht_probe, tlb_probe

Orchestration / Driver skeleton

Use a driver to:

Start victim pinned to victim_cpu.

Wait a short warmup (sleep 0.1).

Start attacker probe pinned to attacker_cpu.

Collect probe CSV and perf stat snapshot for the time window.

Save metadata JSON:

{
  "model": "tinyllama-1.1b-q4_0",
  "quant": "q4_0",
  "ctx": 512,
  "npredict": 64,
  "temp": 0,
  "prompt": "Explain caching ...",
  "victim_cpu": 2,
  "attacker_cpu": 3,
  "probe": "cache",
  "timestamp": "2025-11-11T..."
}


(Driver template can be adapted from earlier examples.)

Data logging format

Probe CSV header (per probe):

ts,probe,model,batch,iters,core,victim_core,iter_idx,cycles


Perf: save the perf stat output as perf_{run_id}.txt or JSON if using perf wrappers.

Frequency trace: record /sys/devices/system/cpu/cpuX/cpufreq/scaling_cur_freq at 10–20 ms sampling and save as freq_{run_id}.csv with ts,freq_khz.

Metadata: meta_{run_id}.json (see sample above).

Analysis

Place or run analysis/analysis.py (or open analysis.ipynb):

Loads all logs/*.csv and metadata.

Computes per-run features: mean, std, median, p90, p99 of probe cycles; normalized miss rates; IPC; uop/stall rates.

Produces histograms, boxplots, PCA scatter, k-means clusters.

Trains simple classifiers (RandomForest / Logistic) to evaluate separability:

membership detection (token present / absent)

model fingerprinting (quant or hidden-size class)

Output directory: analysis/figs/ with PNGs + features_summary.csv.

Run:

python3 analysis/analysis.py
# or open analysis.ipynb for interactive exploration

Perf event list (recommended)

Example perf stat event set (availability depends on CPU):

cycles,instructions,cache-references,cache-misses,LLC-loads,LLC-load-misses,
branch-instructions,branch-misses,dtlb_load_misses,uops_executed.core,
uops_retired,resource_stalls.any


Use perf stat -e <comma-separated-events> -- <command> (or perf_event_open in code for finer control).

Reproducibility & Controls

Baselines:

Probe only (no victim).

Victim only (no attacker).

SMT off (pin attacker/victim to different physical cores).

TurboBoost disabled (or governor change) to test frequency effect.

Repeats: at least 3 runs per point; 1000+ probe iterations per run recommended.

Warmup: discard first 500–1000 iterations as warmup.

Temperature: record CPU temperature; discard runs with thermal throttling.

Ethics & Non-overlap (Cache Telepathy)

This project does NOT perform cache-based reconstruction of GEMM internals (i.e., no Prime+Probe targeted at BLAS/GEMM kernels to recover matrix sizes).

Focus is on SMT sibling contention in predictor/pipeline/TLB/register structures (timing microbenchmarks + perf counters).

Use synthetic data/models you own. Do not attempt to extract proprietary data or model weights. If you discover an unexpected leakage of real data, inform your advisor and follow responsible disclosure.

Troubleshooting

No signal / flat data:

Ensure victim is pinned and single-threaded (-t 1), attacker pinned to SMT sibling.

Increase probe iterations and repeats.

Increase victim workload intensity (-c, -n-predict) to amplify contention.

High noise:

Set CPU governor to performance.

Isolate the physical core using isolcpus or cset.

Close background processes and network activity.

Perf missing events:

Some events are CPU specific; check perf list and adjust.

Expected deliverables

logs/ (raw CSVs, perf snapshots, freq traces, meta JSONs)

analysis/figs/ (histograms, PCA, classification results)

paper/ (methods, figures, discussion, checklist differentiating from Cache Telepathy)

reproducibility.tar.gz containing code + minimal model pointers and README
