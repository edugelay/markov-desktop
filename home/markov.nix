{ config, lib, pkgs, ... }:

{
  home.username = "markov";
  home.homeDirectory = "/home/markov";
  home.stateVersion = "26.05";

  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
  };

  #############################################################################
  # Hyprland
  #############################################################################

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;   # uwsm handles the session
    settings = {
      "$mod" = "SUPER";
      "$term" = "ghostty";
      "$menu" = "fuzzel";

      monitor = ",preferred,auto,1";

      general = {
        gaps_in = 6;
        gaps_out = 14;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ee) rgba(89b4faee) 45deg";
        "col.inactive_border" = "rgba(313244aa)";
        resize_on_border = true;
        layout = "dwindle";
      };

      decoration = {
        rounding = 12;
        active_opacity = 1.0;
        inactive_opacity = 0.94;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          new_optimizations = true;
          xray = true;
        };
        shadow = {
          enabled = true;
          range = 20;
          render_power = 3;
          color = "rgba(11111baa)";
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "wind, 0.05, 0.9, 0.1, 1.05"
          "overshot, 0.13, 0.99, 0.29, 1.1"
          "smoothOut, 0.36, 0, 0.66, -0.56"
        ];
        animation = [
          "windowsIn, 1, 6, overshot, slide"
          "windowsOut, 1, 5, smoothOut, slide"
          "windowsMove, 1, 5, wind, slide"
          "workspaces, 1, 5, wind"
          "fade, 1, 10, default"
          "border, 1, 10, default"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
      };

      exec-once = [
        "waybar"
        "hyprpaper"
        "swaync"
        "wl-paste --watch cliphist store"
        "hypridle"
      ];

      bind = [
        "$mod, Return, exec, $term"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, $term -e yazi"
        "$mod, V, togglefloating"
        "$mod, R, exec, $menu"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        "$mod, F, fullscreen"
        "$mod, L, exec, hyprlock"
        "$mod SHIFT, S, exec, hyprshot -m region"
        "$mod SHIFT, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
      ]
      ++ builtins.concatLists (builtins.genList (i:
        let ws = toString (i + 1); in [
          "$mod, ${ws}, workspace, ${ws}"
          "$mod SHIFT, ${ws}, movetoworkspace, ${ws}"
        ]) 9);

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];
    };
  };

  #############################################################################
  # Bar
  #############################################################################

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      margin = "8 12 0 12";
      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "cpu" "memory" "temperature" "pulseaudio" "network" "tray" ];

      "hyprland/workspaces".format = "{icon}";
      clock = {
        format = "{:%a %d %b  %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };
      cpu.format = "  {usage}%";
      memory.format = "  {}%";
      temperature = {
        critical-threshold = 82;
        format = "  {temperatureC}°C";
      };
      pulseaudio = {
        format = "{icon}  {volume}%";
        format-muted = "  muted";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
      };
      network = {
        format-ethernet = "  {ipaddr}";
        format-disconnected = "  down";
      };
    };
  };

  #############################################################################
  # Terminal / shell
  #############################################################################

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 12;
      background-opacity = 0.92;
      window-padding-x = 12;
      window-padding-y = 12;
      window-decoration = false;
    };
  };

  programs.nushell.enable = true;
  programs.starship.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.bat.enable = true;
  programs.yazi.enable = true;

  programs.git = {
    enable = true;
    userName = "markov";
    # userEmail = "...";
  };

  #############################################################################
  # Lock / idle / wallpaper
  #############################################################################

  programs.hyprlock.enable = true;

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
      };
      listener = [
        { timeout = 600; on-timeout = "loginctl lock-session"; }
        { timeout = 900; on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on"; }
      ];
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "~/Pictures/wallpapers/current.png" ];
      wallpaper = [ ",~/Pictures/wallpapers/current.png" ];
    };
  };
}
