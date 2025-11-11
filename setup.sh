#!/bin/bash
# Quick start script to build probes and verify setup

set -e

echo "=== SMT Contention Project - Quick Start ==="
echo

# Check if we're in the project root
if [ ! -f "README.md" ]; then
    echo "Error: Run this script from the project root directory"
    exit 1
fi

# Build attacker probes
echo "1. Building attacker probes..."
cd attacker
make clean
make
echo "   ✓ Built: cache_probe, tlb_probe, btb_probe, pht_probe"
cd ..

# Check Python dependencies
echo
echo "2. Checking Python dependencies..."
if command -v python3 &> /dev/null; then
    echo "   Python3 found: $(python3 --version)"
    
    # Try to import required packages
    python3 -c "import pandas, numpy, matplotlib, seaborn, sklearn" 2>/dev/null && \
        echo "   ✓ All Python packages available" || \
        echo "   ⚠ Missing packages. Install with: pip3 install -r requirements.txt"
else
    echo "   ⚠ Python3 not found"
fi

# Check system configuration
echo
echo "3. Checking system configuration..."

# Check CPU governor
governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
echo "   CPU Governor: $governor"
if [ "$governor" != "performance" ]; then
    echo "   ⚠ Recommended: Set to 'performance' for experiments"
    echo "     sudo cpupower frequency-set -g performance"
fi

# Check SMT siblings
echo
echo "4. SMT sibling configuration:"
if [ -d "/sys/devices/system/cpu/cpu0/topology" ]; then
    echo "   CPU 0 siblings: $(cat /sys/devices/system/cpu/cpu0/topology/thread_siblings_list)"
    echo "   CPU 1 siblings: $(cat /sys/devices/system/cpu/cpu1/topology/thread_siblings_list)"
    echo "   CPU 2 siblings: $(cat /sys/devices/system/cpu/cpu2/topology/thread_siblings_list)"
    echo "   CPU 3 siblings: $(cat /sys/devices/system/cpu/cpu3/topology/thread_siblings_list)"
else
    echo "   ⚠ Cannot determine SMT topology"
fi

# Test a probe
echo
echo "5. Testing cache_probe..."
./attacker/cache_probe 0 10 > /tmp/test_probe.csv 2>&1 && \
    echo "   ✓ Probe test successful (output: /tmp/test_probe.csv)" || \
    echo "   ⚠ Probe test failed"

echo
echo "=== Setup Complete ==="
echo
echo "Next steps:"
echo "  1. Install llama.cpp (see victim/README.md)"
echo "  2. Download TinyLLaMA model"
echo "  3. Run experiment with driver/driver.py"
echo "  4. Analyze results with analysis/analysis.py"
echo
echo "Example experiment:"
echo "  python3 driver/driver.py \\"
echo "    --victim-bin ~/llama.cpp/main \\"
echo "    --model ~/llama.cpp/models/tinyllama-1.1b-q4_0.gguf \\"
echo "    --victim-cpu 2 --attacker-cpu 6 \\"
echo "    --probe-bin ./attacker/cache_probe \\"
echo "    --probe cache"
