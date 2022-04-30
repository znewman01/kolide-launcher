flake:
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
  kolide-launcher = flake.packages.${pkgs.stdenv.hostPlatform.system}.default;
  osquery = flake.packages.${pkgs.stdenv.hostPlatform.system}.osquery;
  cfg = config.services.kolide-launcher;
in {
  options = {
    services.kolide-launcher = {
      enable = mkEnableOption ''
        Launcher for Kolide.
      '';

      enrollSecretPath = mkOption {
        type = types.path;
        description = ''
          Path to the Kolide enroll secret.
        '';
      };

      rootDirectory = mkOption {
        type = types.path;
        description = ''
          Path to the persistent storage state for Kolide.
        '';
      };

      hostname = mkOption {
        type = types.str;
        default = "k2device.kolide.com";
        description = ''
          Hostname of the Kolide device server.
        '';
      };

      controlHostname = mkOption {
        type = types.str;
        default = "k2control.kolide.com";
        description = ''
          Hostname of the Kolide control server.
        '';
      };

      package = mkOption {
        type = types.package;
        default = kolide-launcher;
        description = ''
          The Kolide package to use with the service.
        '';
      };

      osqueryPackage = mkOption {
        type = types.package;
        default = osquery;
        description = ''
          The osquery package to use with the service.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.kolide-launcher = {
      description = "Kolide launcher";
      documentation = [ "https://www.kolide.com/" ];

      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "3";
        ExecStart = ''
          ${cfg.package}/bin/launcher \
            --with_initial_runner \
            --control \
            --enroll_secret_path ${cfg.enrollSecretPath} \
            --hostname ${cfg.hostname} \
            --root_directory ${cfg.rootDirectory} \
            --osqueryd_path ${cfg.osqueryPackage}/bin/osqueryd \
            --transport jsonrpc \
            --update_channel stable \
            --control_hostname ${cfg.controlHostname}

        '';
      };
    };
  };
}
