{ config, lib, pkgs, ... }:

let
  cfg = config.services.hclient-cli;
in
{
  options.services.hclient-cli = {
    enable = lib.mkEnableOption "LazyCat Microserver hclient-cli";

    package = lib.mkPackageOption pkgs "hclient-cli" { };

    enableAppArmor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable an unconfined AppArmor profile for hclient-cli.
        This can be useful on systems with AppArmor in enforcing mode.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    security.wrappers.hclient-cli = {
      source = "${cfg.package}/lib/hclient-cli/.hclient-cli-wrapped";
      capabilities = "cap_net_admin+ep";
      owner = "root";
      group = "root";
      permissions = "0755";
    };

    security.apparmor.policies."hclient-cli" = lib.mkIf cfg.enableAppArmor {
      profile = ''
        ${cfg.package}/bin/hclient-cli flags=(unconfined) { }
      '';
    };
  };

  meta.maintainers = with lib.maintainers; [ ];
}
