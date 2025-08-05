{ config, pkgs, ... }:

{
  home.stateVersion = "24.05";

  # Basic packages
  home.packages = with pkgs; [
    fastfetch
    bat
    eza
    btop
    ripgrep
    fzf
  ];

  # Programs
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      
      shellAliases = {
        ll = "eza -la";
        ls = "eza";
        cat = "bat";
        rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#PC-NixOS";
      };
    };

    git = {
      enable = true;
      userName = "Your Name";
      userEmail = "your.email@example.com";
    };

    firefox.enable = true;
  };

  # Hyprland configuration
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        "DP-1,3440x1440@175,0x0,1"
        ",preferred,auto,1"
      ];

      input = {
        kb_layout = "us,ru";
        kb_options = "grp:alt_shift_toggle";
        follow_mouse = 1;
        sensitivity = 0;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
      };

      "$mainMod" = "SUPER";

      bind = [
        "$mainMod, Q, exec, kitty"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, thunar"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, wofi --show drun"
        
        # Move focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        
        # Workspaces
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        
        # Move to workspaces
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      exec-once = [
        "waybar"
      ];
    };
  };

  # Waybar
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 30;
      
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [ "pulseaudio" "network" "clock" ];
      
      clock = {
        format = "{:%Y-%m-%d %H:%M}";
      };
      
      network = {
        format-ethernet = "{ipaddr}";
        format-disconnected = "Disconnected";
      };
      
      pulseaudio = {
        format = "{volume}%";
        on-click = "pavucontrol";
      };
    }];
  };
}