#!/bin/bash
set -euo pipefail

# =============================
# Ubuntu 22.04 VM (Google Colab)
# =============================

clear
cat << "EOF"
================================================
   Ubuntu 22.04 VM on Google Colab
================================================
EOF

# =============================
# Configurable Variables
# =============================
VM_DIR="$HOME/vm"
IMG_FILE="$VM_DIR/ubuntu-cloud.img"
SEED_FILE="$VM_DIR/seed.iso"
MEMORY=4096    # 4GB RAM (safe for Colab)
CPUS=2         # Colab CPUs
SSH_PORT=10022 # Exposed port
DISK_SIZE=20G  # Smaller disk for Colab

mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# Install Dependencies
# =============================
if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "[INFO] Installing QEMU & cloud-utils..."
    sudo apt update -y
    sudo apt install -y qemu-system-x86 qemu-utils cloud-image-utils
fi

# =============================
# VM Image Setup
# =============================
if [ ! -f "$IMG_FILE" ]; then
    echo "[INFO] Downloading Ubuntu image..."
    wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    cat > user-data <<EOF
#cloud-config
hostname: ubuntu22
ssh_pwauth: true
chpasswd:
  list: |
    root:root
  expire: false
runcmd:
 - sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
 - systemctl restart ssh
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: ubuntu22
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[INFO] VM setup complete!"
else
    echo "[INFO] VM image found, skipping setup..."
fi

# =============================
# Start VM (No KVM)
# =============================
echo "[INFO] Starting VM..."
exec qemu-system-x86_64 \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -drive file="$IMG_FILE",format=qcow2,if=virtio \
    -drive file="$SEED_FILE",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
    -nographic -serial mon:stdio
