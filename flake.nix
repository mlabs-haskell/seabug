{
  description = "Seabug";
  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs"; };
    cardano-node = {
      url =
        "github:input-output-hk/cardano-node/73f9a746362695dc2cb63ba757fbcabb81733d23";
    };
    flake-utils = { url = "github:numtide/flake-utils"; };
    # https://github.com/hercules-ci/arion/pull/153
    arion = {
      url = "github:t4ccer/arion/69b9109dea2b4d48f35c614456463bd0234e2e80";
    };

    cardano-transaction-lib = {
      url = "github:Plutonomicon/cardano-transaction-lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nft-marketplace = {
      url = "github:mlabs-haskell/nft-marketplace";
      flake = false;
    };

    nft-marketplace-server = {
      url = "github:mlabs-haskell/nft-marketplace-server";
      flake = false;
    };

    ogmios-datum-cache = {
      url = "github:mlabs-haskell/ogmios-datum-cache";
      inputs.nixpkgs.follows = "nixpkgs";
      # flake = false;
    };
  };
  outputs =
    { self
    , nixpkgs
    , cardano-node
    , flake-utils
    , arion
    , nft-marketplace-server
    , ogmios-datum-cache
    , cardano-transaction-lib
    , ...
    }@inputs:
    {
      overlay = final: prev:
        let inherit (final) system; in
        {
          inherit (final.callPackage
            (import "${nft-marketplace-server}/release.nix")
            { nixpkgs = final; }) nft-marketplace-server;

          # TODO: system-agnostic
          inherit (inputs.ogmios-datum-cache.packages.${system}) ogmios-datum-cache;

          cardano-transaction-lib-server =
            cardano-transaction-lib.packages.${system}."cardano-browser-tx-server:exe:cardano-browser-tx-server";
        };
    } //
    flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system};
    in
    rec {
      devShell = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          postgresql
          jq
          curl
          ipfs
          cardano-node.packages.${system}.cardano-cli
          arion.packages.${system}.arion
        ];
      };
      nixosModules.default = import ./nixos-module.nix inputs;
      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixosModules.default
          ({ ... }: { services.seabug.enable = true; })

        ];
      };
    });
}
