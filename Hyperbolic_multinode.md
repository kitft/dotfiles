
# Designing a multi‑node VeRL training stack on Hyperbolic

## Overview

Volcano Engine Reinforcement Learning (​**VeRL**​) is a distributed reinforcement‑learning library that uses **Ray** to orchestrate workers and inference engines such as **vLLM** and **SGLang** [oai_citation:0‡verl.readthedocs.io](https://verl.readthedocs.io/en/latest/start/multinode.html#:~:text=if%20%5B%20,port%3D8265).  Hyperbolic’s on‑demand GPU clusters can be turned into a VeRL training environment by using **one head node** to coordinate the Ray cluster and **multiple worker nodes** for rollouts and model optimisation [oai_citation:1‡verl.readthedocs.io](https://verl.readthedocs.io/en/latest/start/multinode.html#:~:text=1,address%20you%20should%20care%20about).  You can attach network volumes to every instance, mount them via NFS and point your training code at the shared data directory [oai_citation:2‡docs.hyperbolic.xyz](https://docs.hyperbolic.xyz/docs/storage-options#:~:text=Bash).  The high‑level architecture is:

- **GPU nodes** – identical Hyperbolic GPU instances.  One node acts as the Ray **head**, while the remainder are Ray **workers** [oai_citation:3‡verl.readthedocs.io](https://verl.readthedocs.io/en/latest/start/multinode.html#:~:text=1,address%20you%20should%20care%20about).
- **Scratch volume** – optional LVM‑backed volume created from your NVMe drives for caching compiled kernels and other transient files.  This volume is local to each node and mounted at `/workspace`.
- **Network volume** – an NFS‑based volume (Hyperbolic’s “Network Volume”) attached to every node and mounted at `/data`; this holds datasets, config files and model checkpoints [oai_citation:4‡docs.hyperbolic.xyz](https://docs.hyperbolic.xyz/docs/storage-options#:~:text=Bash).
- **VeRL environment** – a Python virtual environment with vLLM, FSDP/Megatron back‑ends and your RL code.  All nodes need the same environment to avoid version mismatches.
- **Orchestration** – Ray is started manually or via SkyPilot/Slurm; the training script runs on the head node and distributes work across workers [oai_citation:5‡verl.readthedocs.io](https://verl.readthedocs.io/en/latest/start/multinode.html#:~:text=if%20%5B%20,port%3D8265).

The following sections outline how to set up this stack and run a distributed VeRL job.

## 1 Create and mount storage volumes

### 1.1 Local scratch volume

High‑throughput RL training benefits from a fast local filesystem for compiled kernels and temporary caches.  You can aggregate multiple NVMe drives into a single logical volume using **LVM**:

```bash
# Identify your NVMe devices (nvme2n1..nvme6n1 in your example) and create a volume group.
sudo apt install -y lvm2
sudo vgcreate vg0 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1
# Allocate all space to a logical volume
sudo lvcreate -n lv_scratch -l 100%FREE vg0
# Format as ext4 and mount at /workspace
sudo mkfs.ext4 /dev/mapper/vg0-lv_scratch
sudo mkdir -p /workspace
# Add to fstab for persistence
echo '/dev/mapper/vg0-lv_scratch /workspace ext4 defaults 0 0' | sudo tee -a /etc/fstab
sudo mount -a

This volume is only accessible on the node where it’s created; it provides local scratch space for the environment and compiled CUDA/ROCm kernels.

1.2 Shared network volume

Hyperbolic’s network volume is an NFS‑backed storage device that you can attach to each node.  To mount it, add a line to /etc/fstab that specifies the virtual IP (you can find it in the instance’s details page) and mount the volume at /data :

# Replace <storage-vip> with the volume’s virtual IP
sudo apt install -y nfs-common
# Persist the mount across reboots
echo "<storage-vip>:/data /data nfs rw,nconnect=16,nfsvers=3 0 0" | sudo tee -a /etc/fstab
sudo mkdir -p /data
sudo mount -a
# Verify that /data is mounted
df -h | grep /data

Use /data to store datasets and checkpoints.  Because it is shared via NFS, all nodes see the same files .  To avoid saturating the network, keep large intermediate files on the local scratch volume.

2 Prepare the software environment

2.1 Base packages and development tools

Each node needs the same system packages and development tools.  A typical setup includes nfs-common, tmux, vim, the Hugging Face CLI and Node.js (for any front‑end helpers).  Use nvm to install Node LTS locally (no sudo):

# Shell environment; run as your normal user
# Install NVM and Node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh"
nvm install --lts

# Install Node packages globally (no sudo)
npm install -g @google/gemini-cli @openai/codex

# Install Python and system dependencies
sudo apt update && sudo apt install -y python3.10 python3.10-venv python3-pip git
pip install --upgrade pip
pip install "huggingface[cli]" hf_transfer

2.2 Clone your code and create a virtual environment
	1.	Clone your repository (including submodules) into the scratch volume:

export HF_TOKEN=… # your Hugging Face token
export WANDB_API_KEY=… # your Weights & Biases API key
cd /workspace
git clone --recurse-submodules https://github.com/kitft/nla
cd nla/verl
git checkout main


	2.	Create a Python environment.  Using a per‑project virtual environment prevents package conflicts:

# Remove old venv if present
rm -rf .venv
python3.10 -m venv .venv
source .venv/bin/activate
# Synchronise dependencies from requirements.txt
pip install --upgrade pip
pip install -r requirements.txt
# Install extra extensions used by VeRL
pip install flash-attn==2.8.2 --no-build-isolation
pip install --no-deps sgl_kernel==0.2.4


	3.	Set environment variables.  Enable fast Hugging Face downloads and log into W&B:

# accelerate HF downloads
export HF_HUB_ENABLE_HF_TRANSFER=1
huggingface-cli login --token $HF_TOKEN
wandb login --relogin --key $WANDB_API_KEY



All nodes should run the same setup script.  You can place the commands above into your dotfiles repository (setup_env.sh) 
