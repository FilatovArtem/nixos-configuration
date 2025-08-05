{ config, lib, pkgs, ... }:

{
  home-manager.useUserPackages = true;
  home-manager.users.artfil-nixos = {
    home.stateVersion = "24.05";
    
    # Базовые настройки home-manager
    home.packages = with pkgs; [
      # Здесь можно добавить пакеты для пользователя
    ];
    
    # Конфигурация программ
    programs = {
      # Например, конфигурация для neovim, git и т.д.
    };
  };
} 