{ config, lib, pkgs, ... }:

let
  snapRoot = "/.snapshots/restic";
in
{
  # bcachefs has no send/receive, so restic is the transport rather than a
  # complement to it. Snapshot first, back up the snapshot, then drop it —
  # otherwise you are backing up a live tree and files change mid-run.

  environment.systemPackages = [ pkgs.restic ];

  services.restic.backups.truenas = {
    initialize = true;

    # Tailscale MagicDNS name of the TrueNAS restic REST server.
    repository = "rest:http://truenas:8000/markov-desktop";

    # Root-only, 0400. Use sops-nix or agenix if you want it in git.
    passwordFile = "/etc/nixos/secrets/restic-password";

    # RESTIC_REST_USERNAME=... / RESTIC_REST_PASSWORD=...
    environmentFile = "/etc/nixos/secrets/restic-env";

    paths = [
      "${snapRoot}/home"
      "/etc/nixos"
      "/var/lib"
    ];

    exclude = [
      # Re-derivable or worthless
      "${snapRoot}/home/*/.cache"
      "${snapRoot}/home/*/.local/share/Steam"
      "${snapRoot}/home/*/.local/share/Trash"
      "${snapRoot}/home/*/.mozilla/firefox/*/cache2"
      "${snapRoot}/home/*/Downloads"
      "/var/lib/systemd/coredump"
      "**/node_modules"
      "**/.direnv"
      "**/target/debug"
    ];

    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "20m";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-hourly 24"
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
      "--keep-yearly 3"
    ];

    # Snapshot /home so the backup sees a consistent tree.
    backupPrepareCommand = ''
      set -eu
      mkdir -p ${snapRoot}
      # Clear a snapshot left behind by a killed run.
      if [ -e ${snapRoot}/home ]; then
        ${pkgs.bcachefs-tools}/bin/bcachefs subvolume delete ${snapRoot}/home || true
      fi
      ${pkgs.bcachefs-tools}/bin/bcachefs subvolume snapshot /home ${snapRoot}/home
    '';

    backupCleanupCommand = ''
      set -eu
      ${pkgs.bcachefs-tools}/bin/bcachefs subvolume delete ${snapRoot}/home || true
    '';
  };

  # The 2TB Seagate holds the actual files. Separate repo and a daily cadence:
  # different data, different retention, and a failure in one doesn't stop the
  # other. Trim the excludes once you've looked at what's actually in there.
  services.restic.backups.archive = {
    initialize = true;
    repository = "rest:http://truenas:8000/markov-archive";
    passwordFile = "/etc/nixos/secrets/restic-password";
    environmentFile = "/etc/nixos/secrets/restic-env";

    paths = [ "/srv/archive" ];

    exclude = [
      "/srv/archive/$RECYCLE.BIN"
      "/srv/archive/System Volume Information"
      "/srv/archive/tmp"
      # Media already served from TrueNAS would just be round-tripping:
      # "/srv/archive/Videos"
    ];

    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 8"
      "--keep-monthly 12"
    ];
  };

  # A backup you have never restored is a hypothesis. Verify a random 5% of
  # the pack files weekly — cheap, and catches bit rot on the TrueNAS side.
  systemd.services.restic-check-truenas = {
    description = "restic repository integrity check";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/nixos/secrets/restic-env";
      ExecStart = ''
        ${pkgs.restic}/bin/restic -r rest:http://truenas:8000/markov-desktop \
          --password-file /etc/nixos/secrets/restic-password \
          check --read-data-subset=5%
      '';
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.restic-check-truenas = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # Shout if a backup or check fails, rather than finding out in six months.
  systemd.services."notify-failure@" = {
    description = "Report failure of %i";
    serviceConfig = {
      Type = "oneshot";
      # Point this at whatever you already use — the Telegram bot from the
      # TrueNAS alerting work would slot straight in here.
      ExecStart = ''${pkgs.writeShellScript "notify-failure" ''
        ${pkgs.systemd}/bin/systemctl status --full --no-pager "$1" | \
          ${pkgs.curl}/bin/curl -s -X POST \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            --data-urlencode "text@-" \
            "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" >/dev/null
      ''} %i'';
      EnvironmentFile = "/etc/nixos/secrets/telegram-env";
    };
  };

  systemd.services.restic-backups-truenas.unitConfig.OnFailure =
    "notify-failure@restic-backups-truenas.service";
  systemd.services.restic-backups-archive.unitConfig.OnFailure =
    "notify-failure@restic-backups-archive.service";
  systemd.services.restic-check-truenas.unitConfig.OnFailure =
    "notify-failure@restic-check-truenas.service";
}
