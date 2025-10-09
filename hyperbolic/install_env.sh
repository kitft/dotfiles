
export PATH="$HOME/.local/bin:$PATH"
cd /scratch/venvs/nla
rm -rf .venv
uv venv --python=3.10.14
. .venv/bin/activate

# Install dependencies from shared code location
cp /workspace/kitf/nla/requirements.txt requirements.txt
sed -i '/-e verl\//d' requirements.txt && echo "-e /workspace/kitf/nla/verl" >> requirements.txt

uv pip sync requirements.txt
uv pip install flash-attn==2.8.2 --no-build-isolation
pip install --no-deps sgl_kernel==0.2.4

# Ensure wandb is installed
uv pip install wandb

# Login to W&B if token is available and wandb command exists
if command -v wandb &> /dev/null && [ -n "$WANDB_API_KEY" ]; then
    wandb login --relogin $WANDB_API_KEY
    echo "✓ Logged into Weights & Biases"
elif [ -n "$WANDB_API_KEY" ]; then
    echo "⚠ wandb command not found, skipping W&B login"
else
    echo "⚠ WANDB_API_KEY not set, skipping W&B login"
fi

echo "✓ VeRL environment installed"

# Create symlink from shared code to local venv
echo "Setting up symlink from shared code to local venv..."
cd /workspace/kitf/nla

# Check if symlink already exists and points to the correct location
if [ -L ".venv" ]; then
    current_target=$(readlink .venv)
    if [ "$current_target" = "/scratch/venvs/nla/.venv" ]; then
        echo "✓ Symlink already correctly configured: /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
    else
        echo "Symlink exists but points to wrong location ($current_target), recreating..."
        rm .venv
        ln -s /scratch/venvs/nla/.venv .venv
        echo "✓ Symlink updated: /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
    fi
elif [ -e ".venv" ]; then
    # It's a regular file or directory, not a symlink
    echo "⚠ .venv exists but is not a symlink, removing and recreating..."
    rm -rf .venv
    ln -s /scratch/venvs/nla/.venv .venv
    echo "✓ Symlink created: /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
else
    # Doesn't exist, create it
    ln -s /scratch/venvs/nla/.venv .venv
    echo "✓ Symlink created: /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
fi
