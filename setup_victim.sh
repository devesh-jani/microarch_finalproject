#!/bin/bash
# Setup script for TinyLLaMA victim workload
# Clones llama.cpp, builds it, and downloads quantized TinyLLaMA models

set -e

INSTALL_DIR="${HOME}/llama.cpp"
MODELS_DIR="${INSTALL_DIR}/models"

echo "=== TinyLLaMA Victim Setup ==="
echo

# Check if llama.cpp already exists
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠  llama.cpp already exists at $INSTALL_DIR"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "Skipping llama.cpp installation"
        exit 0
    fi
fi

# Clone llama.cpp
echo "1. Cloning llama.cpp..."
git clone https://github.com/ggerganov/llama.cpp.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Build llama.cpp
echo
echo "2. Building llama.cpp..."
# Use CMake build system (new default)
# Disable native march to avoid unsupported instructions
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF
cmake --build . --config Release -j$(nproc)
cd ..
echo "   ✓ Build complete"

# Create models directory
mkdir -p "$MODELS_DIR"

# Download TinyLLaMA models
echo
echo "3. Downloading TinyLLaMA models..."
echo "   This may take a few minutes..."

# Q4_0 model (smallest, fastest)
if [ ! -f "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf" ]; then
    echo "   Downloading Q4_0 (4-bit quantization, ~600MB)..."
    wget -q --show-progress \
        https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf \
        -O "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf"
else
    echo "   ✓ Q4_0 model already exists"
fi

# Optionally download other quantization levels
read -p "Download additional quantization levels (Q5_0, Q8_0)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Q5_0 model
    if [ ! -f "$MODELS_DIR/tinyllama-1.1b-q5_0.gguf" ]; then
        echo "   Downloading Q5_0 (5-bit quantization, ~750MB)..."
        wget -q --show-progress \
            https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q5_0.gguf \
            -O "$MODELS_DIR/tinyllama-1.1b-q5_0.gguf"
    else
        echo "   ✓ Q5_0 model already exists"
    fi
    
    # Q8_0 model
    if [ ! -f "$MODELS_DIR/tinyllama-1.1b-q8_0.gguf" ]; then
        echo "   Downloading Q8_0 (8-bit quantization, ~1.1GB)..."
        wget -q --show-progress \
            https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf \
            -O "$MODELS_DIR/tinyllama-1.1b-q8_0.gguf"
    else
        echo "   ✓ Q8_0 model already exists"
    fi
fi

# Test the installation
echo
echo "4. Testing TinyLLaMA inference..."
cd "$INSTALL_DIR"
# Binary is now in build/bin/ directory
./build/bin/llama-cli -m "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf" \
    -t 1 -c 128 -n 10 --temp 0 \
    -p "Hello" 2>&1 | tail -20

echo
echo "=== Setup Complete ==="
echo
echo "Installation summary:"
echo "  llama.cpp: $INSTALL_DIR"
echo "  Models:    $MODELS_DIR"
echo
echo "Available models:"
ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || echo "  (none)"
echo
echo "Test inference command:"
echo "  $INSTALL_DIR/build/bin/llama-cli -m $MODELS_DIR/tinyllama-1.1b-q4_0.gguf -t 1 -c 512 -n 64 --temp 0 -p 'Test'"
echo
echo "Pin to specific CPU (example - CPU 2):"
echo "  taskset -c 2 $INSTALL_DIR/build/bin/llama-cli -m $MODELS_DIR/tinyllama-1.1b-q4_0.gguf -t 1 -c 512 -n 64 --temp 0 -p 'Test'"
