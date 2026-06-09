{ config, lib, pkgs, ... }:

let
  cfg = config.services.openlinkhub;
  installDir = "/home/${cfg.user}/.openlinkhub";
  binaryPath = "${installDir}/OpenLinkHub";

  libPath = lib.makeLibraryPath (with pkgs; [
    stdenv.cc.cc.lib
    glibc
    pipewire
    udev
    libusb1
  ]);

  olhWrapper = pkgs.writeShellScript "openlinkhub-wrapper" ''
    export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "${binaryPath}" "$@"
  '';

  fetchScript = pkgs.writeShellScript "openlinkhub-fetch" ''
    set -euo pipefail
    INSTALL_DIR="${installDir}"
    ARCH="$(${pkgs.coreutils}/bin/uname -m)"
    case "$ARCH" in
      x86_64)  ARCH_TAG="amd64" ;;
      aarch64) ARCH_TAG="arm64"  ;;
      *)
        echo "openlinkhub-fetch: unsupported architecture $ARCH" >&2
        exit 1
        ;;
    esac
    LATEST=$(
      ${pkgs.curl}/bin/curl -fsSL --max-time 10 \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/jurkovic-nikola/OpenLinkHub/releases/latest" \
      | ${pkgs.jq}/bin/jq -r '.tag_name'
    )
    STAMP="$INSTALL_DIR/.version"
    BINARY="${installDir}/OpenLinkHub"
    if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$LATEST" ] && [ -f "$BINARY" ]; then
      echo "openlinkhub-fetch: already at $LATEST"
      exit 0
    fi
    echo "openlinkhub-fetch: installing $LATEST"
    TARBALL="OpenLinkHub_${"\${LATEST}"}_${"\${ARCH_TAG}"}.tar.gz"
    URL="https://github.com/jurkovic-nikola/OpenLinkHub/releases/download/${"\${LATEST}"}/${"\${TARBALL}"}"
    TMP=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$TMP"' EXIT
    ${pkgs.curl}/bin/curl -fsSL "$URL" -o "$TMP/olh.tar.gz"
    ${pkgs.gnutar}/bin/tar -I '${pkgs.gzip}/bin/gzip' -xf "$TMP/olh.tar.gz" -C "$TMP"
    EXTRACTED=$(${pkgs.coreutils}/bin/ls "$TMP" | ${pkgs.gnugrep}/bin/grep -v 'olh.tar.gz' | ${pkgs.coreutils}/bin/head -1)
    ${pkgs.coreutils}/bin/mkdir -p "$INSTALL_DIR"
    ${pkgs.rsync}/bin/rsync -a --delete --exclude='.version' "$TMP/$EXTRACTED/" "$INSTALL_DIR/"
    ${pkgs.coreutils}/bin/chmod +x "${binaryPath}"

    # Patch the ELF interpreter so NixOS's stub-ld doesn't intercept it.
    # LD_LIBRARY_PATH alone cannot help — the binary's PT_INTERP must point
    # at the real glibc dynamic linker in the Nix store.
    INTERP=$(ls ${pkgs.glibc}/lib/ld-linux-x86-64.so.* | head -1)
    ${pkgs.patchelf}/bin/patchelf \
      --set-interpreter "$INTERP" \
      --set-rpath "${pkgs.lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc.lib glibc pipewire udev libusb1 ])}" \
      "${binaryPath}"

    echo "$LATEST" > "$STAMP"
    ${pkgs.coreutils}/bin/chown ${cfg.user} "$STAMP" 2>/dev/null || true
    echo "openlinkhub-fetch: done"
  '';
in
{
  options.services.openlinkhub = {
    enable = lib.mkEnableOption "OpenLinkHub";
    user = lib.mkOption {
      type = lib.types.str;
      example = "alice";
      description = "User to add to the openlinkhub group.";
    };
  };

  config = lib.mkIf cfg.enable {

    users.groups.openlinkhub = {};
    users.users.${cfg.user}.extraGroups = [ "openlinkhub" "input" ];

    # Never fatal — network not available during switch-root.
    # The systemd service handles first-boot download after network is up.
    system.activationScripts.openlinkhub-install = {
      deps = [ "users" "groups" ];
      text = ''
        ${fetchScript} || echo "openlinkhub: offline during activation, will fetch at boot"
      '';
    };

    services.udev.extraRules = ''
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c3f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c4e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c32", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c33", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c39", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c1c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c2a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c35", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c40", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c36", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c37", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c41", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c1a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c0b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c10", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c42", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c20", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c21", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c22", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c43", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bfe", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bd7", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bfd", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc6", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc4", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb3", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b10", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b11", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b07", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bab", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc5", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b7c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b7d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdc", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1ba6", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b00", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a34", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b9b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc9", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c23", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c05", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c06", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c07", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c1e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c08", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c23", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c27", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c1f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1be3", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bdb", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c0c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b03", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b70", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c0d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b93", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b94", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b5d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b4c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb8", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c17", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c18", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c19", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b7e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b80", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bf0", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bf2", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b08", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b9e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b75", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b5e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a62", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a64", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bac", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b55", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b6b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b49", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb2", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b01", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b62", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb5", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb4", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c07", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bca", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b0e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b09", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc7", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc8", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c02", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c06", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c1b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b3b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b2d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b98", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b8b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1ba0", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a88", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b5c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bb6", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b79", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b3e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b1e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b4b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bc0", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b51", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c08", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c09", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c0a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b04", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b7a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b89", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b5a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c56", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a45", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a3e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a3d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b36", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b4f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b6e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b38", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b20", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2a08", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1c00", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1d00", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b33", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b48", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a43", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a44", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1baf", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bcf", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c57", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c55", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="3a08", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="3a05", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2a0f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c2d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a73", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b74", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bf1", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a41", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a42", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a40", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a3f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b81", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b34", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b17", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a69", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1bff", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0c14", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b39", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b7f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b28", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b2a", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b11", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b0e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b0d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b23", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2a03", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b21", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b1b", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="1b2e", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2a0c", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b32", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="2b0f", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b1c", ATTRS{idProduct}=="0a51", MODE="0660", GROUP="openlinkhub"
      # Aquacomputer
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2e95", ATTRS{idProduct}=="434d", MODE="0660", GROUP="openlinkhub"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2e95", ATTRS{idProduct}=="434e", MODE="0660", GROUP="openlinkhub"
      # uinput
      KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
    '';

    systemd.services.openlinkhub = {
      description = "Open source interface for iCUE LINK System Hub, Corsair AIOs and Hubs";
      wants    = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "openlinkhub-install.service" ];
      after    = [ "network-online.target" "local-fs.target" "openlinkhub-install.service" ];
      startLimitIntervalSec = 60;
      startLimitBurst = 5;
      serviceConfig = {
        ExecStart      = "${olhWrapper}";
        ExecReload     = "/run/current-system/sw/bin/kill -s HUP $MAINPID";
        WorkingDirectory = installDir;
        Restart        = "always";
        RestartSec     = 5;
        User           = cfg.user;
        Group          = "openlinkhub";
        PrivateTmp     = true;
        ProtectSystem  = "strict";
        ProtectHome    = "read-only";
        ReadWritePaths = [ installDir ];
        DeviceAllow    = [ "char-usb_device rw" "char-input rw" "char-hidraw rw" ];
      };
    };

    systemd.services.openlinkhub-install = {
      description = "Download latest OpenLinkHub release";
      after  = [ "network-online.target" ];
      wants  = [ "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = cfg.user;
        ExecStart       = fetchScript;
      };
    };
  };
}
