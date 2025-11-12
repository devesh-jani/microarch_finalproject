# Microarchitecture Side-Channel Analysis Results

## Experiment Overview
- **Platform:** artemisia (Intel x86, 56 cores, SMT enabled)
- **Victim:** TinyLLaMA-1.1B (Q4_0 quantization)
- **Attacker Probes:** Cache, TLB, BTB, PHT
- **CPU Pairing:** Victim on CPU 0, Attacker on CPU 56 (SMT siblings)

## Data Collection Summary
- **Total Runs:** 69
- **Total Measurements:** 103,500
- **Probe Types:** cache (34,500), tlb (34,500), btb (17,250), pht (17,250)

## Key Findings

### 1. Signal Strength by Microarchitectural Resource

#### Cache Probe
- **Mean Latency:** ~16,500-17,000 cycles
- **Standard Deviation:** ~600-3,500 cycles
- **Observation:** High variance indicates strong contention signal
- **Interpretation:** L1/L2/L3 cache sharing creates measurable interference

#### TLB Probe
- **Mean Latency:** ~5,900-6,300 cycles  
- **Standard Deviation:** ~280-760 cycles
- **Observation:** Lower base latency, moderate variance
- **Interpretation:** TLB contention present but less noisy than cache

### 2. Classification Performance

#### Context Size Detection (ctx: 128 / 512 / 2048)
- **Accuracy:** 66.7%
- **Best Features:** mean (19.3%), p10 (18.3%), median (16.8%)
- **Interpretation:** Timing channels can partially distinguish input sequence lengths
- **Security Impact:** Attacker can infer approximate prompt length

#### Decoding Strategy Detection (greedy vs sample)
- **Accuracy:** 90.5%
- **Best Features:** median (20.7%), mean (19.2%), p90 (18.7%)
- **Interpretation:** Strong signal separates deterministic vs stochastic generation
- **Security Impact:** Attacker can determine if model is using temperature sampling

### 3. Feature Importance
Top timing features for classification:
1. **Mean:** Overall average latency
2. **Median:** Robust central tendency  
3. **P90/P99:** Tail latency (captures outliers from cache misses)
4. **P10:** Lower bound (captures fast-path execution)

### 4. Visualization Outputs
Generated figures:
- `boxplot_ctx.png` - Context size timing distributions
- `boxplot_ctx_cache.png` / `boxplot_ctx_tlb.png` - Per-probe breakdowns
- `hist_cycles_*.png` - Cycle histograms by probe type
- `confusion_ctx.png` / `confusion_decoding.png` - Classifier confusion matrices
- `feature_importance_*.png` - Feature ranking plots
- `pca_runs.png` - PCA projection of run configurations

## Next Steps for Weight/Output Extraction

### Phase 1: Characterize Signal Quality ✓ (COMPLETED)
- Ran parameter sweeps to understand baseline contention
- Identified cache probe as highest-signal channel
- Validated ML classifiers can distinguish configurations

### Phase 2: Develop Attack Primitives (IN PROGRESS)
1. **Prime+Probe for Matrix Ops:**
   - Target cache lines used in matrix multiplication (attention/FFN layers)
   - Use cache probe with fine-grained timing to detect access patterns
   
2. **Branch Pattern Analysis:**
   - Use BTB/PHT probes to detect activation function branches (ReLU, softmax)
   - Conditional branches may leak sign/magnitude information
   
3. **Memory Access Pattern Fingerprinting:**
   - TLB probe to detect page access patterns during weight loading
   - Different quantization formats (Q4_0 vs Q8_0) may have distinct patterns

### Phase 3: Targeted Extraction
1. **Token-by-Token Leakage:**
   - Monitor timing during autoregressive generation
   - Each token prediction may have unique computational signature
   
2. **Weight Reconstruction:**
   - Use cache timing to infer which weight blocks are accessed
   - Correlate access patterns with known model architecture
   
3. **Output Prediction:**
   - Build classifier to predict most-likely output tokens from timing
   - Leverage softmax computation timing differences

## Recommendations

### For Signal Improvement:
1. Run longer captures (increase iterations from 1500 to 5000+)
2. Add CPU frequency locking to reduce measurement noise
3. Isolate CPUs from OS scheduler to minimize interference

### For Extraction Attacks:
1. Focus on **cache probe** (highest variance = best signal)
2. Target specific model layers (attention heads most promising)
3. Use timing histograms to build per-token timing signatures

### For Complete Sweep:
Run `./run_all_sweeps.sh` to collect:
- Working set sweep (8 configs × 3 repeats = 24 runs)
- Context size sweep (12 configs × 3 repeats = 36 runs)  
- Access pattern sweep (4 configs × 3 repeats = 12 runs)
- **Total:** 72 runs, ~108,000 additional measurements

## Ethical Considerations
This research demonstrates privacy risks in shared-core (SMT) environments:
- Cloud providers should disable SMT for ML inference workloads
- Sensitive models should run on isolated physical cores
- Side-channel defenses (noise injection, constant-time ops) needed for LLM deployment

