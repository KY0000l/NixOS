# OpenLinkHub NixOS Module

I started this module more than a month ago after buying some Corsair fans... And knowing absolutely nothing about the inner workings of NixOS and systemd. I chose to fix and refine it every day while hitting my token limits on Claude.

## What it actually does

NixOS doesn't use a standard FHS filesystem layout, which means pre-built Linux binaries almost always fail to run out of the box. The OpenLinkHub binary links against `libpipewire`, `libudev`, `libusb`, and glibc — none of which exist at the paths the binary expects. On top of that, NixOS intercepts any binary with a missing ELF interpreter and prints a "not usable on NixOS" error before it even gets a chance to start.

The module solves this in two steps. First, after downloading the binary, it uses `patchelf` to rewrite the binary's ELF interpreter to point at the real glibc dynamic linker in the Nix store, and embeds the Nix store paths of all required libraries directly into the binary's RPATH. Second, a small wrapper script sets `LD_LIBRARY_PATH` as a fallback before exec'ing the binary.

For device access, Corsair hardware exposes itself over both USB (`/dev/bus/usb/*`) and HID (`/dev/hidraw*`). The module installs udev rules that assign both sets of device nodes to an `openlinkhub` group, and the service runs as your user who is added to that group. The systemd service also needs explicit `DeviceAllow` entries for both `char-usb_device` and `char-hidraw` — without those, systemd's device sandboxing blocks access regardless of what the filesystem permissions say.

## The two systemd services

**`openlinkhub-install.service`** — A oneshot service that runs at boot after the network comes up. It hits the GitHub API to find the latest release tag, compares it against a `.version` stamp file in `~/.openlinkhub/`, and downloads and extracts the tarball if anything has changed. It also runs as an activation script during `nixos-rebuild switch`, though that part is best-effort only — if the network isn't up yet during activation it just logs a message and moves on, leaving the boot-time service to handle it. This is why the service requires a working internet connection on first install: there's no binary bundled in the Nix store, it has to be fetched.

**`openlinkhub.service`** — The main daemon. It has a `requires`/`after` dependency on `openlinkhub-install.service` so systemd guarantees the binary exists before trying to start it. It runs as your user from `~/.openlinkhub/` as its working directory, which is where OpenLinkHub looks for its `config.json`, device database, and RGB profiles.

## Files

Everything lives in `/home/$USER/.openlinkhub/` — the binary, config, device database, RGB profiles, and the `.version` stamp. This is intentional: the upstream install script does the same thing, and it means you can update OpenLinkHub independently of your NixOS config by deleting `.version` and running `systemctl restart openlinkhub-install`.

## Usage

```nix
imports = [ ./modules/openlinkhub.nix ];

services.openlinkhub = {
  enable = true;
  user = "youruser";
};
```

You'll also want to remove `openlinkhub` from `environment.systemPackages` if it's there — the nixpkgs version installs its own conflicting system service.

(and install these dependencies "go, usbutils, pkg-config")

## Caveats

This is super fragile and not polished or good at all, but it works, at least for now. It bricked my system multiple times due to systemd service misconfiguration. The services are extremely fragile and somehow won't work without a working internet connection on first install. If you want to do a rewrite or have any better, more declarative solutions, be my guest.

"Writeup done by me" - Claude
