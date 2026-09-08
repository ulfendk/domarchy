<p align="center">
    <img src="screenshot.png" alt="omarchy"/>
</p>

# domarchy (Dockerized Omarchy)

Beautiful, Modern & Opinionated Dockerized Linux. This repo exists primarily as a personal sandbox for testing and developing Omarchy configuration scripts in a fully isolated environment. It also aims to make Omarchy accessible to anyone who wants to try it without committing to a full installation or dual boot setup.

## Getting Started

```bash
docker compose up -d
```

Connect to the VM display with any VNC client at `localhost:5900`, e.g. TigerVNC, RealVNC Viewer, Remmina (`vnc://localhost:5900`), or macOS Screen Sharing (`vnc://localhost:5900`). No password is set.

**N.B.** On the first run you will be greeted by the Omarchy installer. Complete the installation manually before using the system. Subsequent starts will boot directly into Omarchy.

## Testing on a Server with Portainer

Every push to `main` (and every `v*` tag) is built and published to GHCR by [`ghcr.yml`](.github/workflows/ghcr.yml), so the test server doesn't need to build the image itself:

- `ghcr.io/ulfendk/domarchy:latest` / `:edge` - latest `main`
- `ghcr.io/ulfendk/domarchy:sha-xxxxxxx` - a specific commit
- `ghcr.io/ulfendk/domarchy:X.Y.Z` - a tagged release

`ghcr.io/ulfendk/domarchy` is public (verified via an anonymous pull), so Portainer can pull it with no registry credentials configured. If a future push ever comes back private, check the package's settings page (`github.com/ulfendk/domarchy/pkgs/container/domarchy`) and set visibility to **Public**.

In Portainer, add a stack pointing at this repository with **Compose path** set to `docker-compose.ghcr.yml` (or paste that file's contents into the Web editor) and deploy. Since the image is public, no registry credentials are needed. To pick up a new push, use the stack's **Pull and redeploy** action (or re-deploy after re-pointing the image tag at a specific `sha-` build).

The Omarchy installer only runs once, on the very first boot - `data/omarchy.qcow2` persists the installed system across redeploys (as long as that volume isn't wiped), so day-to-day VNC testing never touches the installer again. **Pull and redeploy** in Portainer swaps the image but keeps the volume, so it's safe to use for picking up new pushes.

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
