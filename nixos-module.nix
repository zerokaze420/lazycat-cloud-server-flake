{ config, lib, pkgs, ... }:

let
  cfg = config.services.hclient-cli;
in
{
  options.services.hclient-cli = {
    enable = lib.mkEnableOption "LazyCat Microserver hclient-cli";

    package = lib.mkPackageOption pkgs "hclient-cli" { };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tux";
      description = ''
        User to run the daemon as. If null, the daemon runs as root.
        Set this to your desktop user when you want the daemon to reuse the
        user's hclient-cli config and login state.
      '';
    };

    group = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "users";
      description = "Group to run the daemon as when services.hclient-cli.user is set.";
    };

    configDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/tux/.config/hportal-client";
      description = ''
        Optional hclient-cli config directory used by the daemon via HCLIENT_CLI_CFG.
        Leave null to use the upstream default for the selected daemon user.
      '';
    };

    daemon = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Run hclient-cli daemon as a declarative systemd service.
          This replaces the upstream `hclient-cli install` managed-service flow.
        '';
      };

      tunMode = lib.mkOption {
        type = lib.types.enum [ "enabled" "disabled" ];
        default = "enabled";
        description = "TUN mode passed to hclient-cli daemon.";
      };

      proxyMode = lib.mkOption {
        type = lib.types.enum [ "enabled" "disabled" ];
        default = "enabled";
        description = "Proxy mode passed to hclient-cli daemon.";
      };

      proxyListenAddr = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:61090";
        description = "Proxy listen address passed to hclient-cli daemon.";
      };
    };

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

    systemd.services.hclient-cli = lib.mkIf cfg.daemon.enable {
      description = "LazyCat Microserver hclient-cli daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = lib.optionalAttrs (cfg.configDir != null) {
        HCLIENT_CLI_CFG = cfg.configDir;
      };

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/hclient-cli daemon --tun ${cfg.daemon.tunMode} --proxy ${cfg.daemon.proxyMode} --proxy-listen-addr ${lib.escapeShellArg cfg.daemon.proxyListenAddr}";
        Restart = "on-failure";
        RestartSec = 5;
      } // lib.optionalAttrs (cfg.user != null) {
        User = cfg.user;
      } // lib.optionalAttrs (cfg.group != null) {
        Group = cfg.group;
      };
    };

    security.apparmor.policies."hclient-cli" = lib.mkIf cfg.enableAppArmor {
      profile = ''
        ${cfg.package}/bin/hclient-cli flags=(unconfined) { }
      '';
    };
  };

  meta.maintainers = with lib.maintainers; [ ];
}
