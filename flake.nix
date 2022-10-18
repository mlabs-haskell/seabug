{
  description = "Seabug";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

    # TODO change after it's merged
    nft-marketplace-frontend.url = "/home/ccr/mlabs/nft-marketplace"; # github:mlabs-haskell/nft-marketplace/aciceri/nix;

    nft-marketplace-server.url = "/home/ccr/mlabs/nft-marketplace-server"; # github:mlabs-haskell/nft-marketplace-server;

    seabug-contracts.url = github:mlabs-haskell/seabug-contracts/23f49cf05d6230a8c1f63924ac9e61d1e1c0d5a8;
  };
  outputs =
    { self
    , nixpkgs
    , nft-marketplace-frontend
    , nft-marketplace-server
    , seabug-contracts
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
          imports = [
            inputs.nft-marketplace-frontend.nixosModules.nft-marketplace-frontend
            inputs.nft-marketplace-server.nixosModules.nft-marketplace-server
            ./nix/seabug.nix
          ];
          nixpkgs.overlays = with inputs; [
            nft-marketplace-frontend.overlays.nft-marketplace-frontend
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
