{ pkgs, lib, config, options, ... }:

with lib;
let
  cfg = config.services.grafana-agent;
  prettyJSON = conf:
    pkgs.runCommand "grafana-agent-config.json" { } ''
      echo '${builtins.toJSON conf}' | ${pkgs.jq}/bin/jq 'del(._module)' > $out
    '';
in
{
  options.services.grafana-agent = {
    enable = mkEnableOption "grafana-agent";

    user = mkOption {
      type = types.str;
      default = "grafana-agent";
    };

    group = mkOption {
      type = types.str;
      default = "grafana-agent";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/grafana-agent";
    };

    configuration = mkOption {
      type = (pkgs.formats.json { }).type;
      default = {
        server = {
          http_listen_port = 12345;
          http_listen_address = "localhost";

          grpc_listen_address = "localhost";
        };
        prometheus.wal_directory = "/tmp/wal";
      };
    };

    extraConfiguration = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.grafana-agent ];

    users.groups.${cfg.group} = { };

    users.extraUsers.grafana-agent = {
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      extraGroups = [ "systemd-journal" ];
    };

    systemd.services.grafana-agent = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      postStart = ''
        ${pkgs.coreutils}/bin/sleep 5
        echo "Executing bogus kill..."
        ${pkgs.procps}/bin/kill -0 $MAINPID &>/dev/null
        echo "\$MAINPID exists"
      '';

      script =
        let conf = prettyJSON (recursiveUpdate cfg.configuration cfg.extraConfiguration); in
        ''
          HOSTNAME=$(${pkgs.nettools}/bin/hostname) ${pkgs.grafana-agent}/bin/agent --config.file=${conf} --config.expand-env=true
        '';

      serviceConfig =
        {
          User = cfg.user;
          Restart = "always";
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "full";
          DevicePolicy = "closed";
          NoNewPrivileges = true;
          WorkingDirectory = cfg.dataDir;
        };
    };
  };
}
