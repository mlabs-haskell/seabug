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
      url = "github:hercules-ci/arion/bd3e2fe4e372d0b5f965f25f27c5eb7c1a618c4a";
    };
  };
  outputs = { self, nixpkgs, cardano-node, flake-utils, arion }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
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
      });
}
