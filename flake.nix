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
  };
  outputs = { self, nixpkgs, cardano-node, flake-utils, arion }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            arion.packages.${system}.arion
            cardano-node.packages.${system}.cardano-cli
            curl
            httpie
            ipfs
            jq
            postgresql
            shfmt
            expect
          ];
        };
      });
}
