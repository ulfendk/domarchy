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

# Audio is optional: only wire up -audiodev when a real PulseAudio socket
# is mounted at /tmp/pulse.socket (see the docker-compose volume). A
# missing/unusable socket makes QEMU exit immediately, which would kill
# the whole container. Servers without a host PulseAudio session (e.g.
# Portainer test boxes) just get no sound instead of a boot loop.
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

# Start QEMU in the background (instead of exec'ing it straight away) so we
# can wait for its VNC server to actually be accepting connections before
# xrdp is allowed to bridge an RDP client through to it - starting xrdp
# immediately in parallel let clients race QEMU's own startup, especially
# right after a fresh disk format, and fail with a raw ECONNREFUSED/
# EINPROGRESS instead of xrdp's own (much more generous) retry loop.
qemu-system-x86_64 \
    -m $MEMORY -smp $CPUS -machine q35,accel=kvm:tcg \
    -drive file="$DISK",format=qcow2 \
    $CDROM_OPTION \
    -boot order=$BOOT_ORDER \
    -display vnc=127.0.0.1:0 \
    -device VGA,edid=on,xres=1920,yres=1080,vgamem_mb=32 \
    "${AUDIO_ARGS[@]}" \
    -net user,smb=/shared \
    -net nic &
QEMU_PID=$!

# Forward termination so `docker stop` / a Portainer stop still shuts the
# VM down cleanly instead of hanging until the kill timeout.
trap 'kill -TERM "$QEMU_PID" 2>/dev/null' TERM INT

echo "Waiting for QEMU's VNC server on 127.0.0.1:5900..."
for _ in $(seq 1 120); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo "QEMU exited before its VNC server came up."
        wait "$QEMU_PID"
        exit $?
    fi
    (exec 3<>/dev/tcp/127.0.0.1/5900) 2>/dev/null && exec 3<&- 3>&- && break
    sleep 1
done

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

wait "$QEMU_PID"
