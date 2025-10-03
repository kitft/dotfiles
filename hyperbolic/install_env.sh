cd /scratch/venvs/nla
rm -rf .venv
uv venv --python=3.10.14
source .venv/bin/activate

# Install dependencies from shared code location
cp /workspace/kitf/nla/verl/requirements.txt requirements.txt
uv pip sync requirements.txt
uv pip install flash-attn==2.8.2 --no-build-isolation
pip install --no-deps sgl_kernel==0.2.4

# Ensure wandb is installed
uv pip install wandb

echo "✓ VeRL environment installed"

# Create symlink from shared code to local venv
echo "Creating symlink from shared code to local venv..."
cd /workspace/kitf/nla/verl
if [ -L ".venv" ] || [ -d ".venv" ]; then
    rm -rf .venv
fi
ln -s /scratch/venvs/nla/.venv .venv
echo "✓ Symlink created: /workspace/kitf/nla/verl/.venv -> /scratch/venvs/nla/.venv"
