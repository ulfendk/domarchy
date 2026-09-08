#!/bin/bash

DISK=/data/omarchy.qcow2
ISO=/data/omarchy.iso
MEMORY=${MEMORY:-8G}
CPUS=${CPUS:-4}

if [[ ! -f "$ISO" ]]; then
    echo "Downloading Omarchy ISO..."
    wget -O "$ISO" "https://iso.omarchy.org/omarchy-4.0.0.iso" || echo "Download failed"
fi

# Check if this is first boot (disk doesn't exist)
if [[ ! -f "$DISK" ]]; then
    echo "Creating disk image..."
    qemu-img create -f qcow2 "$DISK" 50G
    CDROM_OPTION="-cdrom $ISO"
    BOOT_ORDER="dc"
else
    echo "Starting Omarchy..."
    CDROM_OPTION=""
    BOOT_ORDER="d"
fi

# RDP access: xrdp listens on 3389 and bridges straight through to QEMU's
# VNC framebuffer on 127.0.0.1:5900 (see xrdp.ini), so any RDP client can
# drive the VM without anything extra running inside the guest.
mkdir -p /var/run/xrdp /var/log/xrdp
# Clear stale pid files from a previous run of this same container (e.g.
# after a crash + restart) - xrdp-sesman/xrdp refuse to start otherwise.
rm -f /var/run/xrdp-sesman.pid /var/run/xrdp.pid
[[ -f /etc/xrdp/rsakeys.ini ]] || xrdp-keygen xrdp /etc/xrdp/rsakeys.ini

xrdp-sesman &
xrdp --nodaemon &

# Audio is optional: only wire up -audiodev when a real PulseAudio socket
# is mounted at /tmp/pulse.socket (see the docker-compose volume). A
# missing/unusable socket makes QEMU exit immediately, which - since QEMU
# is the container's main process - kills the whole container. Servers
# without a host PulseAudio session (e.g. Portainer test boxes) just get
# no sound instead of a boot loop.
AUDIO_ARGS=()
if [[ -S /tmp/pulse.socket ]]; then
    AUDIO_ARGS=(
        -audiodev pa,id=audio0,server=unix:/tmp/pulse.socket
        -device ich9-intel-hda
        -device hda-output,audiodev=audio0
    )
else
    echo "No PulseAudio socket at /tmp/pulse.socket - starting without audio."
fi

exec qemu-system-x86_64 \
    -m $MEMORY -smp $CPUS -machine q35,accel=kvm:tcg \
    -drive file="$DISK",format=qcow2 \
    $CDROM_OPTION \
    -boot order=$BOOT_ORDER \
    -display vnc=127.0.0.1:0 \
    -device VGA,edid=on,xres=1920,yres=1080,vgamem_mb=32 \
    "${AUDIO_ARGS[@]}" \
    -net user,smb=/shared \
    -net nic
