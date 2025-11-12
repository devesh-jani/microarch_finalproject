#!/bin/bash
# Simple non-interactive setup for TinyLLaMA victim workload
# Downloads only Q4_0 model by default

set -e

INSTALL_DIR="${HOME}/llama.cpp"
MODELS_DIR="${INSTALL_DIR}/models"

echo "=== TinyLLaMA Victim Setup (Non-Interactive) ==="
echo

# Check if llama.cpp already exists
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠  llama.cpp already exists at $INSTALL_DIR"
    echo "   Removing and reinstalling..."
    rm -rf "$INSTALL_DIR"
fi

# Clone llama.cpp
echo "1. Cloning llama.cpp..."
git clone https://github.com/ggerganov/llama.cpp.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Build llama.cpp with compatible settings
echo
echo "2. Building llama.cpp (this takes ~2-5 minutes)..."
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF
cmake --build . --config Release -j$(nproc)
cd ..
echo "   ✓ Build complete"

# Create models directory
mkdir -p "$MODELS_DIR"

# Download Q4_0 model only
echo
echo "3. Downloading TinyLLaMA Q4_0 model (~600MB)..."
if [ ! -f "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf" ]; then
    wget -q --show-progress \
        https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_0.gguf \
        -O "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf"
    echo "   ✓ Download complete"
else
    echo "   ✓ Model already exists"
fi

# Test the installation
echo
echo "4. Testing TinyLLaMA inference..."
cd "$INSTALL_DIR"
./build/bin/llama-cli -m "$MODELS_DIR/tinyllama-1.1b-q4_0.gguf" \
    -t 1 -c 128 -n 10 --temp 0 \
    -p "Hello" 2>&1 | tail -20

echo
echo "=== Setup Complete ==="
echo
echo "Installation summary:"
echo "  llama.cpp: $INSTALL_DIR"
echo "  Binary:    $INSTALL_DIR/build/bin/llama-cli"
echo "  Model:     $MODELS_DIR/tinyllama-1.1b-q4_0.gguf"
echo
echo "Test command:"
echo "  $INSTALL_DIR/build/bin/llama-cli -m $MODELS_DIR/tinyllama-1.1b-q4_0.gguf -t 1 -c 512 -n 64 --temp 0 -p 'Test'"
echo
echo "NOTE: To download additional models (Q5_0, Q8_0), run:"
echo "  cd $MODELS_DIR"
echo "  wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q5_0.gguf -O tinyllama-1.1b-q5_0.gguf"
echo "  wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf -O tinyllama-1.1b-q8_0.gguf"
