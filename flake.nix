{
  description = "Seabug";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # TODO change after they are merged
    nft-marketplace-frontend.url = "github:mlabs-haskell/nft-marketplace";

    # TODO change after they are merged
    nft-marketplace-server.url = "github:mlabs-haskell/nft-marketplace-server/aciceri/nix";

    cardano-node.url = "github:input-output-hk/cardano-node/1.35.4";

    plutus-use-cases = {
      url = "github:mlabs-haskell/plutus-use-cases/a8251270d17f67c6d2bfa9f55c15668b85567e05";
      flake = false;
    };
  };
  outputs =
    { self
    , nixpkgs
    , nft-marketplace-frontend
    , nft-marketplace-server
    , cardano-node
    , plutus-use-cases
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
              seabug.frontend-maker = nft-marketplace-frontend.lib.make-frontend pkgs.system;
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

      packages = lib.perSystem (system: {
        prepare-wallet = pkgsFor.${system}.callPackage ./scripts/prepare-wallet.nix {
          inherit plutus-use-cases;
          cardano-cli = cardano-node.packages.${system}.cardano-cli;
        };
      });

      apps = lib.perSystem (system: {
        vm = {
          type = "app";
          program = "${self.nixosConfigurations.seabug-vm.config.system.build.vm}/bin/run-seabug-vm";
        };
        prepare-wallet = {
          type = "app";
          program = "${self.packages.${system}.prepare-wallet}/bin/prepare-wallet";
        };
      });
    };
}
