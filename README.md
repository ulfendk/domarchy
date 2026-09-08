<p align="center">
    <img src="screenshot.png" alt="omarchy"/>
</p>

# domarchy (Dockerized Omarchy)

Beautiful, Modern & Opinionated Dockerized Linux. This repo exists primarily as a personal sandbox for testing and developing Omarchy configuration scripts in a fully isolated environment. It also aims to make Omarchy accessible to anyone who wants to try it without committing to a full installation or dual boot setup.

## Getting Started

```bash
docker compose up -d
```

**N.B.** `xrdp` isn't packaged in the official Arch repos, so the first `docker compose build` compiles it from the AUR - expect that step to take a few extra minutes.

Connect to the VM display with any RDP client at `localhost:3389`, e.g.:

```bash
xfreerdp /v:localhost:3389 /sec:rdp /cert:ignore
```

Or point Microsoft Remote Desktop / Remmina / mstsc.exe at `localhost:3389`.

**N.B.** The RDP login prompt is just a gate in front of the VM's display - type any username/password (they're ignored) and you'll land straight on the Omarchy screen. On the first run that's the Omarchy installer; complete the installation manually before using the system. Subsequent starts will boot directly into Omarchy.

## Testing on a Server with Portainer

Every push to `main` (and every `v*` tag) is built and published to GHCR by [`ghcr.yml`](.github/workflows/ghcr.yml) - no need to build the AUR/ffmpeg toolchain on the test server itself:

- `ghcr.io/ulfendk/domarchy:latest` / `:edge` - latest `main`
- `ghcr.io/ulfendk/domarchy:sha-xxxxxxx` - a specific commit
- `ghcr.io/ulfendk/domarchy:X.Y.Z` - a tagged release

**One-time step:** GHCR packages don't automatically inherit their repo's visibility. After the first workflow run, go to the package page (`github.com/ulfendk/domarchy/pkgs/container/domarchy` -> Package settings) and set visibility to **Public**, otherwise Portainer will get a 401/403 trying to pull it.

In Portainer, add a stack pointing at this repository with **Compose path** set to `docker-compose.ghcr.yml` (or paste that file's contents into the Web editor) and deploy. Since the image is public, no registry credentials are needed. To pick up a new push, use the stack's **Pull and redeploy** action (or re-deploy after re-pointing the image tag at a specific `sha-` build).

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
