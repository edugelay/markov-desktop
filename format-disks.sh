#!/usr/bin/env bash
# Partition + format the two 500G SSDs as a single tiered bcachefs.
#
#   Samsung 970 EVO Plus  -> ESP (1G) + bcachefs member "fast"
#   Crucial MX500 500G    -> ESP (1G) + bcachefs member "slow"
#
#   WD SN750 (WDS500G3X0C)  -> Windows. UNTOUCHED.
#   Seagate ST2000DM008 2TB -> archive. UNTOUCHED.
#
# NOTE: kernel device names (sda, nvme0n1) differ between the installed system
# and the rescue ISO -- they are assigned in probe order, not by hardware.
# Everything below uses /dev/disk/by-id, which is stable. Never substitute
# /dev/sdX here, however obvious it looks at the time.
#
# Get the paths with:  ls -l /dev/disk/by-id/ | grep -v part

set -euo pipefail

FAST="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNZFN502006R"
SLOW="/dev/disk/by-id/ata-CT500MX500SSD1_2028E2B63EE7"

# Positive assertions: each target must match this model string. Safer than a
# blocklist -- a blocklist fails open when device names move, which is the
# exact bug this script had before.
FAST_MODEL="Samsung SSD 970 EVO Plus"
SLOW_MODEL="CT500MX500SSD1"

die() { echo "FATAL: $*" >&2; exit 1; }

check_target() {
  local dev="$1" want_model="$2" label="$3"

  [[ "$dev" == *REPLACE_ME* ]] && die "$label: fill in the by-id path first."
  [[ -b "$dev" ]] || die "$label: $dev is not a block device."

  local real; real="$(readlink -f "$dev")"
  local base; base="$(basename "$real")"

  # Must be a whole disk, not a partition.
  [[ "$(lsblk -ndo TYPE "$real")" == "disk" ]] \
    || die "$label: $real is not a whole disk."

  # Model must match what we expect to be erasing.
  local model; model="$(lsblk -ndo MODEL "$real" | xargs)"
  [[ "$model" == *"$want_model"* ]] \
    || die "$label: expected model '$want_model', found '$model' on $real."

  # Refuse anything carrying NTFS -- that is Windows, whatever it is called
  # this boot.
  if lsblk -no FSTYPE "$real" | grep -qi ntfs; then
    die "$label: $real contains an NTFS filesystem. That is the Windows disk."
  fi

  # Refuse anything over 1TB -- the archive disk is 1.8T, the targets are 500G.
  local bytes; bytes="$(blockdev --getsize64 "$real")"
  (( bytes < 1000000000000 )) \
    || die "$label: $real is $((bytes/1000000000))GB, too large to be a target."

  echo "  OK  $label -> $real  ($model, $((bytes/1000000000))GB)"
}

echo "Verifying targets:"
check_target "$FAST" "$FAST_MODEL" "FAST"
check_target "$SLOW" "$SLOW_MODEL" "SLOW"

echo
echo "These two disks will be COMPLETELY ERASED."
echo "Everything else, including Windows and the 2TB archive, is untouched."
read -rp "Type ERASE to continue: " ok
[[ "$ok" == "ERASE" ]] || exit 1

# ---- partition -------------------------------------------------------------
for dev in "$FAST" "$SLOW"; do
  wipefs -a "$dev"
  sgdisk --zap-all "$dev"
  sgdisk -n1:1M:+1G  -t1:ef00 -c1:"ESP"      "$dev"
  sgdisk -n2:0:0     -t2:8300 -c2:"bcachefs" "$dev"
done
partprobe "$FAST" "$SLOW"
udevadm settle

mkfs.vfat -F32 -n BOOT    "${FAST}-part1"
mkfs.vfat -F32 -n BOOTALT "${SLOW}-part1"

# ---- format bcachefs -------------------------------------------------------
# foreground/promote on the NVMe, background on the SATA SSD.
# metadata_replicas=2 keeps the btree on both devices; data_replicas=1 means
# data on a failed member is gone -- that is what the TrueNAS backup covers.
bcachefs format \
  --fs_label=nixroot \
  --label=fast.samsung970 "${FAST}-part2" \
  --label=slow.mx500      "${SLOW}-part2" \
  --foreground_target=fast \
  --promote_target=fast \
  --background_target=slow \
  --compression=zstd:1 \
  --background_compression=zstd:8 \
  --metadata_replicas=2 \
  --data_replicas=1 \
  --discard

# ---- mount + subvolumes ----------------------------------------------------
mount -t bcachefs "${FAST}-part2:${SLOW}-part2" /mnt

bcachefs subvolume create /mnt/home
bcachefs subvolume create /mnt/nix
bcachefs subvolume create /mnt/var
bcachefs subvolume create /mnt/var/log
mkdir -p /mnt/.snapshots

mkdir -p /mnt/boot /mnt/boot-fallback
mount "${FAST}-part1" /mnt/boot
mount "${SLOW}-part1" /mnt/boot-fallback

echo
echo "Done. Put these in filesystems.nix:"
echo "  fast = \"${FAST}-part2\";"
echo "  slow = \"${SLOW}-part2\";"
