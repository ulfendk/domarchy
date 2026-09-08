<p align="center">
    <img src="screenshot.png" alt="omarchy"/>
</p>

# domarchy (Dockerized Omarchy)

Beautiful, Modern & Opinionated Dockerized Linux. This repo exists primarily as a personal sandbox for testing and developing Omarchy configuration scripts in a fully isolated environment. It also aims to make Omarchy accessible to anyone who wants to try it without committing to a full installation or dual boot setup.

## Getting Started

```bash
docker compose up -d
```

Connect to the VM display with a VNC client at `localhost:5900` - no password is set. Use TigerVNC, RealVNC Viewer, or Remmina (`vnc://localhost:5900`); **avoid macOS's built-in Screen Sharing app**, which tries Apple's proprietary authentication scheme first and will sit on a password prompt forever against a plain VNC server like QEMU's - it never falls back to standard VNC auth cleanly.

**N.B.** On the first run you will be greeted by the Omarchy installer. Complete the installation manually before using the system. Subsequent starts will boot directly into Omarchy.

## RDP into the Desktop (hypr-rdp)

VNC above is really just a remote KVM for the installer and for troubleshooting - it streams QEMU's raw framebuffer, has no encoding, and no audio. For actually using or performance-testing the Omarchy desktop, install [hypr-rdp](https://github.com/MuNeNiCK/hypr-rdp) *inside* the guest once Omarchy is installed: it's a native RDP server written for Hyprland (H.264-encoded, PipeWire audio, clipboard), so it talks straight to the running compositor instead of screen-scraping a VNC framebuffer - much closer to a real remote-desktop experience.

Port 3389 is already forwarded from the container straight into the guest (see `entrypoint.sh`); nothing listens there until you do this one-time setup. Open a terminal in Omarchy (over the VNC connection above) and run:

```bash
curl -Lo hypr-rdp.tar.gz \
  https://github.com/MuNeNiCK/hypr-rdp/releases/download/v0.1.5/hypr-rdp-v0.1.5-x86_64-linux.tar.gz
tar xzf hypr-rdp.tar.gz
sudo install -Dm755 hypr-rdp /usr/local/bin/hypr-rdp
```

(Check [the releases page](https://github.com/MuNeNiCK/hypr-rdp/releases) for a newer version - or install via AUR instead with `yay -S hypr-rdp`, which Omarchy already ships `yay` for.)

Then wire it up as a systemd user service tied to the Hyprland session (Omarchy runs Hyprland under `uwsm`, which sets up `graphical-session.target`, so this starts and stops with your desktop session automatically):

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/hypr-rdp.service <<'EOF'
[Unit]
Description=hypr-rdp - Native RDP server for Hyprland
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=/usr/local/bin/hypr-rdp -u YOUR_USERNAME -p YOUR_PASSWORD --bind 0.0.0.0:3389
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now hypr-rdp.service
```

Replace `YOUR_USERNAME`/`YOUR_PASSWORD` with real credentials first - unlike the VNC port, this one is worth actually protecting since it's a real login. Then connect any RDP client (`xfreerdp`, Microsoft Remote Desktop, Remmina) to `<host>:3389`.

## Testing on a Server with Portainer

Every push to `main` (and every `v*` tag) is built and published to GHCR by [`ghcr.yml`](.github/workflows/ghcr.yml), so the test server doesn't need to build the image itself:

- `ghcr.io/ulfendk/domarchy:latest` / `:edge` - latest `main`
- `ghcr.io/ulfendk/domarchy:sha-xxxxxxx` - a specific commit
- `ghcr.io/ulfendk/domarchy:X.Y.Z` - a tagged release

`ghcr.io/ulfendk/domarchy` is public (verified via an anonymous pull), so Portainer can pull it with no registry credentials configured. If a future push ever comes back private, check the package's settings page (`github.com/ulfendk/domarchy/pkgs/container/domarchy`) and set visibility to **Public**.

In Portainer, add a stack pointing at this repository with **Compose path** set to `docker-compose.ghcr.yml` (or paste that file's contents into the Web editor) and deploy. Since the image is public, no registry credentials are needed. To pick up a new push, use the stack's **Pull and redeploy** action (or re-deploy after re-pointing the image tag at a specific `sha-` build).

The Omarchy installer only runs once, on the very first boot - `data/omarchy.qcow2` persists the installed system (and the hypr-rdp service enabled inside it) across redeploys, as long as that volume isn't wiped. **Pull and redeploy** in Portainer swaps the image but keeps the volume, so it's safe to use for picking up new pushes without redoing either setup step.

**N.B.** If the container ever crashes and restarts *before* the Omarchy installer finished, `data/omarchy.qcow2` will already exist as an empty disk - the entrypoint only attaches the install ISO when that file doesn't exist yet. Delete `data/omarchy.qcow2` (or the whole `data/` volume) before redeploying to get a fresh installer boot.

## Keyboard Shortcuts

When running domarchy inside Omarchy, keyboard shortcuts will be intercepted by the host. To forward all shortcuts to the container, add the following to your host's Hyprland config:

```bash
nvim ~/.config/hypr/hyprland.conf
```

Add at the bottom:

```
bind = SUPER, F10, submap, passthrough
submap = passthrough
bind = SUPER, F10, submap, reset
submap = reset
```

Then reload Hyprland:

```bash
omarchy-restart-hyprctl
```

Now press `Super + F10` to toggle keyboard passthrough to the container.

## Sharing Files

The `shared/` folder in the project root is automatically mounted inside the container and exposed via Samba. You can access it from within the Omarchy guest without credentials.

To connect from within the VM, mount the share:

```
smb://10.0.2.4/qemu
```

**N.B.** `10.0.2.4` is hardcoded by QEMU for the Samba share and will never change regardless of the container's IP.
