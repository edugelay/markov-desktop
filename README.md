# markov-desktop

NixOS config for an AMD desktop dual-booting Windows 11.

## Disks

| Device | Model | Role |
|---|---|---|
| `nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNZFN502006R` | Samsung 970 EVO Plus | bcachefs `fast` — foreground + promote |
| `ata-CT500MX500SSD1_2028E2B63EE7` | Crucial MX500 500G | bcachefs `slow` — background |
| `nvme-WDS500G3X0C-00SJG0_210767805963` | WD SN750 | **Windows 11 — never touch** |
| `ata-ST2000DM008-2FR102_WFL50TMH` | Seagate 2TB | archive, mounted at `/srv/archive` |

Kernel device names (`sda`, `nvme0n1`) differ between the installed system and
the rescue ISO — they are assigned in probe order. Everything here uses
`/dev/disk/by-id`. Never substitute `/dev/sdX`.

## Layout

- `flake.nix` — two outputs: `markov-desktop` and `installer`
- `kernel.nix` — single source of truth for the kernel, imported by both
- `filesystems.nix` — bcachefs root, archive mount, Windows mount
- `configuration.nix` — system config
- `backup.nix` — restic to TrueNAS
- `iso.nix` — rescue ISO, same flake.lock as the system
- `home/markov.nix` — Hyprland + Catppuccin Mocha
- `format-disks.sh` — destructive; guard-railed by disk model
- `check-rescue.sh` — is the rescue stick stale?

## Install

    sudo ./format-disks.sh
    sudo nixos-install --flake /run/archive/files#markov-desktop

## Rescue stick

bcachefs bumps its on-disk format, and an out-of-date `bcachefs-tools` cannot
read a newer filesystem. Generation rollback does not save you. So:

    nix flake update --commit-lock-file
    ./check-rescue.sh || nix build .#installer
    nixos-rebuild boot --flake .#markov-desktop

Build the ISO *before* the new module touches the filesystem, not after.

## Secrets

Referenced but not stored here — root-only, 0400, under `/etc/nixos/secrets/`:
`restic-password`, `restic-env`, `telegram-env`. Move to sops-nix eventually.

## Outstanding

- [ ] Windows EFI device handle via the EDK2 shell (`configuration.nix`)
- [ ] `/mnt/windows` NTFS UUID
- [ ] `powercfg /h off` + `RealTimeIsUniversal` on the Windows side
- [ ] GPU: uncomment the AMD or NVIDIA branch in `configuration.nix`
- [ ] Trim `backup.nix` archive excludes
- [ ] `hyprland` flake input is declared but unused — wire up or drop
