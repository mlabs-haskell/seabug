{ arion, ... }:

{ lib, config, ... }:

with lib;

let cfg = config.services.seabug; in

{
  options.services.seabug = {
    enable = mkEnableOption ''
      Seabug
    '';
  };

  imports = [
    arion.nixosModules.arion
  ];

  config = mkIf cfg.enable {
    virtualisation.arion = {
      backend = "podman-socket";
      projects.seabug.settings.imports = [ ./arion-compose.nix ];
    };
  };
}
