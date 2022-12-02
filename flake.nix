{
  description = "Seabug";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

    # TODO change after they are merged
    nft-marketplace-frontend.url = github:mlabs-haskell/nft-marketplace/aciceri/contract-updates-and-nix;

    nft-marketplace-server.url = github:mlabs-haskell/nft-marketplace-server/aciceri/nix;
  };
  outputs =
    { self
    , nixpkgs
    , nft-marketplace-frontend
    , nft-marketplace-server
    } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      pkgsFor = lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system});

      lib = nixpkgs.lib.extend (self: super: {
        perSystem = super.genAttrs supportedSystems;
      });
    in
    {
      nixosModules = {
        seabug = {
          imports = with inputs; [
            nft-marketplace-server.nixosModules.nft-marketplace-server
            ./nix/seabug.nix
            ({pkgs, ...}: {
              seabug.frontend-maker = nft-marketplace-frontend.lib.make-frontend "x86_64-linux";
            })
          ];
          nixpkgs.overlays = with inputs; [
            nft-marketplace-server.overlays.nft-marketplace-server
          ];
        };
        default = self.modules.seabug;
      };

      nixosConfigurations.seabug-vm = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.seabug
          ./nix/vm.nix
        ];
      };

      apps = lib.perSystem (system: {
        vm = {
          type = "app";
          program = "${self.nixosConfigurations.seabug-vm.config.system.build.vm}/bin/run-seabug-vm";
        };
      });
    };
}
