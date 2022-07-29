{ arionModule, seabugOverlay }:
{ lib, config, ... }:

with lib; let
  cfg = config.services.seabug;
in
{
  options.services.seabug = {
    enable = mkEnableOption ''
      Seabug
    '';
  };

  imports = [
    arionModule
  ];

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 8080 ];
    nixpkgs.overlays = [ seabugOverlay ];
    virtualisation.arion = {
      backend = "podman-socket";
      # backend = "docker";
      projects.seabug.settings.imports = [ ./arion-compose.nix ];

    };
  };
}
