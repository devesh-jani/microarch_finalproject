Microarchitectural Characterization of SMT Contention Channels using TinyLLaMA

This project measures how variations in TinyLLaMA inference (working set, quantization width, access pattern) create observable contention on shared microarchitectural structures between SMT siblings (cache, TLB, ROB/register file, BTB/PHT). A TinyLLaMA victim runs on one logical CPU while a purpose-built attacker probe runs on its SMT sibling to record timing/perf signals.

## Repository layout

```
README.md                <- you are here
attacker/                <- C microbench probes & Makefile
  ├─ common.h
  ├─ btb_probe.c
  ├─ pht_probe.c
  ├─ tlb_probe.c
  ├─ cache_probe.c
  ├─ rob_probe.c  (optional)
  └─ Makefile
victim/                  <- tinyllama/llama.cpp wrapper or run instructions
driver/                  <- orchestration / sweep automation
analysis/                <- analysis.py / analysis.ipynb
logs/                    <- run logs (csv + perf + freq + meta)
env_metadata.json        <- recorded system metadata
paper/                   <- drafts, figures
```

## TL;DR

- Pin TinyLLaMA (llama.cpp) victim to one logical CPU.
- Pin an attacker probe (cache/tlb/btb/pht/rob) to the SMT sibling.
- Sweep TinyLLaMA parameters and collect probe cycles, perf counters, and core frequency.
- Analyze separability and fingerprinting in `analysis/`.

## Requirements

- Intel x86 CPU with SMT and TurboBoost enabled
- Linux (Ubuntu/Debian recommended)
- Tools: gcc, make, python3 (≥3.8) with pandas, numpy, matplotlib, scikit-learn; perf (Linux perf_event)
- llama.cpp (TinyLLaMA inference; quantized `*.gguf` models)
- sudo may be needed for some perf events / MSR access

Recommended: set CPU governor to performance during experiments:

```
sudo cpupower frequency-set -g performance
```

## Quick start

1) Build attacker probes

```
cd attacker
make
```

This produces: `btb_probe`, `pht_probe`, `tlb_probe`, `cache_probe` (and optionally `rob_probe`). Each prints CSV to cwd.

2) Prepare TinyLLaMA victim (example)

Build llama.cpp per its README; place a quantized model (e.g., `models/tinyllama-1.1b-q4_0.gguf`). Pin to CPU 2:

```
taskset -c 2 ./main -m models/tinyllama-1.1b-q4_0.gguf -t 1 -c 512 -n-predict 64 --temp 0 -p "Explain caching with an example."
```

Notes:
- `-t 1` ensures single-threaded victim.
- Adjust `-c`, `-n-predict`, and model quant per sweep.

3) Run an attacker probe on the SMT sibling (e.g., CPU 3):

```
taskset -c 3 ./cache_probe 3
```

## Standardized run ID and logging structure

Goals: unique and time-sortable run identifiers, compact encoding of key knobs, analysis-friendly directory layout.

Run ID format (compact):

```
YYYYMMDDThhmmssZ-host-v<V>a<A>-<probe>-<mdl>-<quant>-c<C>-n<N>-<dec>-seed<S>-r<R>
```

Where:
- `host`: short hostname; `v<V>a<A>`: victim/attacker CPUs; `probe`: cache|tlb|btb|pht|rob
- `mdl`: short model tag (e.g., `tinyllama1p1b`)
- `quant`: e.g., `q4_0`, `q5_0`, `q8_0`
- `dec`: `g`=greedy, `s`=sampling
- `R`: 1-based repeat index (zero-padded)

Example:

```
20251111T154210Z-hades-v2a3-cache-tinyllama1p1b-q4_0-c512-n64-g-seed42-r001
```

Directory structure:

```
logs/
  runs/
    <run_id>/
      meta.json           # full metadata for this run
      probe.csv           # attacker probe output
      perf.txt            # perf stat output (or perf.json if structured)
      freq.csv            # ts,freq_khz (10–20 ms sampling)
      victim_stdout.txt   # victim stdout/stderr
      attacker_stdout.txt # probe stdout/stderr
      timings.json        # start/end and phase durations
  index.csv               # one row per run with key fields + path
  latest -> runs/<run_id> # optional symlink to most recent run
```

Probe CSV header (per probe):

```
ts,probe,model,batch,iters,core,victim_core,iter_idx,cycles
```

### Sample metadata (meta.json)

```
{
  "run_id": "20251111T154210Z-hades-v2a3-cache-tinyllama1p1b-q4_0-c512-n64-g-seed42-r001",
  "timestamp_utc": "2025-11-11T15:42:10Z",
  "host": "hades",
  "victim_cpu": 2,
  "attacker_cpu": 3,
  "probe": "cache",
  "model": "models/tinyllama-1.1b-q4_0.gguf",
  "model_tag": "tinyllama1p1b",
  "quant": "q4_0",
  "ctx": 512,
  "npredict": 64,
  "decoding": "greedy",
  "temp": 0.0,
  "top_k": null,
  "top_p": null,
  "seed": 42,
  "repeat_idx": 1,
  "prompt_label": "low_diversity",
  "prompt_hash": "ab12cd34",
  "durations_ms": {"victim_warmup": 100, "probe": 3000, "total": 3200},
  "versions": {
    "driver": "v0.1",
    "probe_git": null,
    "analysis_git": null,
    "llama_cpp_git": null
  },
  "cpu_governor": "performance",
  "turbo": true,
  "kernel": "6.5.0-ubuntu",
  "notes": "S1 sweep"
}
```

`logs/index.csv` columns (suggested):

```
run_id,timestamp_utc,path,host,victim_cpu,attacker_cpu,probe,model_tag,quant,ctx,npredict,decoding,temp,seed,repeat_idx,prompt_label,prompt_hash
```

## Orchestration (driver flow)

1. Generate `run_id` and create `logs/runs/<run_id>/`.
2. Start victim pinned to `victim_cpu`; wait short warmup (e.g., 100 ms).
3. Start attacker probe pinned to `attacker_cpu` for a fixed window/iters.
4. Collect probe CSV, `perf stat` snapshot, and frequency trace.
5. Write `meta.json` and `timings.json`; append a row to `logs/index.csv`.

## Recommended sweeps

Run each combination with ≥3 repeats for variance estimation; discard 500–1000 warmup iterations.

S1: Working set / Context
- `-c ∈ {128, 512, 2048}`; `-n-predict ∈ {16, 64, 256}`
- quant fixed (`q4_0`)
- probes: `cache_probe`, `tlb_probe`

S2: Width / Compute proxy (quant)
- quant ∈ {`q4_0`, `q5_0`, `q8_0`} (or different `n_embd` models)
- `-c 512`, `-n-predict 64`, greedy
- probes: `rob_probe` / regfile-focused; collect uops/resource_stalls via perf

S3: Access pattern / Sparsity
- decoding: greedy (`--temp 0`) vs sampling (`--temp 1.0 --top-k 40 --top-p 0.95`)
- prompts: low-diversity vs high-diversity
- `-c 512`, `-n-predict 64`
- probes: `btb_probe`, `pht_probe`, `tlb_probe`

## Analysis

`analysis/analysis.py` (or `analysis.ipynb`) should:
- Load all `logs/runs/*/probe.csv` and the corresponding `meta.json`.
- Compute per-run stats: mean/median/std, p90/p99 of probe cycles; normalized miss rates; IPC; uop/stall ratios.
- Produce histograms, boxplots, PCA scatter, k-means clusters.
- Train simple classifiers (RandomForest/Logistic) for:
  - membership detection (token present/absent)
  - model fingerprinting (quant/width class)
- Write figures to `analysis/figs/` and `features_summary.csv`.

Run:

```
python3 analysis/analysis.py
# or open analysis.ipynb for interactive exploration
```

## Perf events (example set)

Availability depends on CPU:

```
cycles,instructions,cache-references,cache-misses,LLC-loads,LLC-load-misses,
branch-instructions,branch-misses,dtlb_load_misses,uops_executed.core,
uops_retired,resource_stalls.any
```

Use `perf stat -e <comma-separated-events> -- <command>` or `perf_event_open` in code for fine control.

## Reproducibility & controls

Baselines:
- Probe only (no victim)
- Victim only (no attacker)
- SMT off (pin to different physical cores)
- TurboBoost disabled (or governor change)

Guidelines:
- Repeats: ≥3 per point; ≥1000 probe iterations per run
- Warmup: discard first 500–1000 iterations
- Record CPU temperature; discard throttled runs

## Ethics & scope

This project does not perform cache-based reconstruction of GEMM internals (no Prime+Probe against BLAS/GEMM). Focus is on SMT sibling contention in predictor/pipeline/TLB/register structures using timing microbenchmarks and perf counters. Use synthetic data/models you own; do not attempt to extract proprietary data. If unexpected leakage is observed, inform your advisor and follow responsible disclosure.

## Troubleshooting

No signal / flat data:
- Ensure victim is pinned and single-threaded (`-t 1`), attacker pinned to SMT sibling
- Increase probe iterations and repeats
- Increase victim intensity (`-c`, `-n-predict`)

High noise:
- Set CPU governor to performance
- Isolate the physical core (`isolcpus` or `cset`)
- Close background processes and network activity

Perf missing events:
- Events are CPU-specific; check `perf list` and adjust

## Expected deliverables

- `logs/` (raw CSVs, perf snapshots, freq traces, meta JSONs)
- `analysis/figs/` (histograms, PCA, classification results)
- `paper/` (methods, figures, discussion, differentiation from Cache Telepathy)
- `reproducibility.tar.gz` containing code + minimal model pointers and README
