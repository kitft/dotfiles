cd /scratch/venvs/nla
rm -rf .venv
uv venv --python=3.10.14
source .venv/bin/activate

# Install dependencies from shared code location
cp /workspace/kitf/nla/verl/requirements.txt requirements.txt
uv pip sync requirements.txt
uv pip install flash-attn==2.8.2 --no-build-isolation
pip install --no-deps sgl_kernel==0.2.4
echo "✓ VeRL environment installed"
