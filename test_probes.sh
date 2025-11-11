#!/bin/bash
# test_probes.sh - Quick test of all probes to verify they work

echo "Testing all attacker probes..."
echo

cd /mnt/ncsudrive/d/dhjani2/microarch_finalproject/attacker

for probe in cache_probe tlb_probe btb_probe pht_probe; do
    echo "=== Testing $probe ==="
    if [ -f "$probe" ]; then
        ./$probe 0 5 | head -8
        echo "✓ $probe working"
    else
        echo "✗ $probe not found (run 'make' first)"
    fi
    echo
done

echo "All probe tests complete!"
