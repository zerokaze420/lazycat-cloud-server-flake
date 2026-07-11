{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hclient-cli;
in
{
  options.programs.hclient-cli = {
    enable = lib.mkEnableOption "LazyCat Microserver hclient-cli";

    package = lib.mkPackageOption pkgs "hclient-cli" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ];
  };

  meta.maintainers = with lib.maintainers; [ ];
}
