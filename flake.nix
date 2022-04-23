{
  description = "Seabug";
  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs"; };
    cardano-node = {
      url =
        "github:input-output-hk/cardano-node/73f9a746362695dc2cb63ba757fbcabb81733d23";
    };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };
  outputs = { self, nixpkgs, cardano-node, flake-utils }:
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
          ];
        };
      });
}
