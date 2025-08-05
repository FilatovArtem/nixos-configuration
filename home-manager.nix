{ config, pkgs, inputs, lib, ... }:

let
  username = "artfil-nixos";
in
{
  home-manager.users.${username} = { ... }: {
    home.stateVersion = "24.05";

    programs.zsh.enable = true;
    programs.git = {
      enable = true;
      userName = "Your Name";
      userEmail = "your.email@example.com";
    };

    home.packages = with pkgs; [
      fastfetch bat eza btop ripgrep fzf yazi
    ];

    # Пример конфигурации Hyprland (если нужно)
    # wayland.windowManager.hyprland.enable = true;
  };
}
