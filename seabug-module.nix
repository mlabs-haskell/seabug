{arionModule, seabugOverlay}: {
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.seabug;
in {
  options.services.seabug = {
    enable = mkEnableOption ''
      Seabug
    '';
  };

  imports = [
    arionModule
  ];

  config = mkIf cfg.enable {
    nixpkgs.overlays = [seabugOverlay];
    virtualisation.arion = {
      backend = "podman-socket";
      projects.seabug.settings.imports = [./arion-compose.nix];
    };
  };
}
