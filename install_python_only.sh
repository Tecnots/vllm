#!/bin/bash
set -e

echo "🚀 Installing vLLM Python code (preserving precompiled binaries)"
echo "================================================================"

# Step 1: Find where vLLM is installed
VLLM_PATH=$(python -c "import vllm, os; print(os.path.dirname(vllm.__file__))")
echo "✓ Found vLLM installation at: $VLLM_PATH"

# Step 2: Backup the compiled binaries
echo "📦 Backing up compiled binaries..."
BACKUP_DIR="/tmp/vllm_binaries_backup"
mkdir -p "$BACKUP_DIR"

# Backup all .so files (compiled extensions)
find "$VLLM_PATH" -name "*.so" -exec cp {} "$BACKUP_DIR/" \; 2>/dev/null || true
echo "✓ Backed up $(ls -1 $BACKUP_DIR/*.so 2>/dev/null | wc -l) binary files"

# Step 3: Install your Python code
echo "🔧 Installing Python code from fork..."
cd /vllm-fork

# Copy all Python files, preserving directory structure
rsync -av --include='*/' --include='*.py' --exclude='*' vllm/ "$VLLM_PATH/"

echo "✓ Python files copied"

# Step 4: Restore the compiled binaries
echo "🔄 Restoring compiled binaries..."
if [ "$(ls -A $BACKUP_DIR)" ]; then
    find "$VLLM_PATH" -type f -name "*.so" -delete
    cp "$BACKUP_DIR"/*.so "$VLLM_PATH"/ 2>/dev/null || true
    
    # Also check subdirectories
    for so_file in "$BACKUP_DIR"/*.so; do
        filename=$(basename "$so_file")
        # Find where this .so file should go
        original_path=$(find "$VLLM_PATH" -type d -name "$(dirname $filename)" 2>/dev/null | head -1)
        if [ -n "$original_path" ]; then
            cp "$so_file" "$original_path/" 2>/dev/null || true
        fi
    done
    echo "✓ Restored binary files"
else
    echo "⚠️  No binaries to restore (this is OK if using fresh install)"
fi

# Step 5: Verify installation
echo "🧪 Verifying installation..."
python -c "import vllm; print(f'vLLM version: {vllm.__version__}')" || exit 1
python -c "from vllm import LLM; print('✓ vLLM imports successfully')" || exit 1

echo ""
echo "✅ Installation complete!"
echo "   Python code: from your fork"
echo "   CUDA binaries: from precompiled vllm==0.6.3"