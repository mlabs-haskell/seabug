{
  description = "Seabug";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

    cardano-node.url = github:input-output-hk/cardano-node/73f9a746362695dc2cb63ba757fbcabb81733d23; # TODO: is there a particular reason to explicitely pin this version?

    arion.url = github:hercules-ci/arion;

    cardano-transaction-lib = {
      url = github:Plutonomicon/cardano-transaction-lib/seabug-deployment;
      # inputs.nixpkgs.follows = "nixpkgs"; # TODO: should we follow this?
    };

    dream2nix = {
      url = github:nix-community/dream2nix;
      inputs.nixpkgs.follows = "nixpkgs";
    };


    nft-marketplace = {
      url = github:mlabs-haskell/nft-marketplace;
      flake = false;
    };

    nft-marketplace-server = {
      url = github:synthetica9/nft-marketplace-server/syn/fix-release;
      flake = false;
    };

    # nft-marketplace-server needs some specific versions.
    nixpkgs-nft-marketplace-server.url = github:nixos/nixpkgs/2cf9db0e3d45b9d00f16f2836cb1297bcadc475e;

    ogmios-datum-cache = {
      url = github:mlabs-haskell/ogmios-datum-cache;
      # inputs.nixpkgs.follows = "nixpkgs"; # TODO: should we follow this?
      # flake = false;
    };
  };
  outputs =
    { self
    , nixpkgs
    , cardano-node
    , arion
    , nft-marketplace-server
    , ogmios-datum-cache
    , cardano-transaction-lib
    , ...
    } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      perSystem = nixpkgs.lib.genAttrs supportedSystems;

      overlays.default = final: prev:
        let
          inherit (final) system;
        in
        {
          inherit
            (final.callPackage
              (import "${nft-marketplace-server}/release.nix")
              { nixpkgs = inputs.nixpkgs-nft-marketplace-server.legacyPackages.${system}; })
            nft-marketplace-server
            ;

          # TODO: system-agnostic
          inherit (inputs.ogmios-datum-cache.packages.${system}) ogmios-datum-cache;

          cardano-transaction-lib-server =
            cardano-transaction-lib.packages.${system}."cardano-browser-tx-server:exe:cardano-browser-tx-server";
        };

      pkgsFor = system:
        import nixpkgs {
          inherit system;
          overlays = [ overlays.default ];
        };

      nixosModules.default = import ./seabug-module.nix {
        arionModule = arion.nixosModules.arion;
        seabugOverlay = overlays.default;
      };

      # Build with `nix build nixosConfigurations.seabug.config.system.build.toplevel`
      # Run with ./result
      nixosConfigurations.seabug-vm =
        let
          system = "x86_64-linux";
          pkgs = pkgsFor system;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            nixosModules.default # Seabug module
            ({ pkgs, ... }: {
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
                autoResize = true;
              };

              boot = {
                growPartition = true;
                kernelParams = [ "console=ttyS0" "boot.shell_on_fail" ];
                loader.timeout = 5;
              };
              services.seabug.enable = true;
              users.users.root.password = "toor";
              users.mutableUsers = false;
              environment.systemPackages = with pkgs; [ htop curl ];

              virtualisation = {
                diskSize = 8000; # MB
                memorySize = 2048; # MB
                writableStoreUseTmpfs = false;
              };
              services.qemuGuest.enable = true;

              services.openssh.enable = true;
              services.openssh.permitRootLogin = "yes";
            })
          ];
        };

      apps = perSystem (system:
        let
          pkgs = pkgsFor system;
          vm = nixosConfigurations.seabug-vm.config.system.build.vm;
          program = pkgs.writeShellScript "run-vm" ''
            set -euo pipefail
            # set -x

            [ -x nixos.qcow2 ] && echo "⚠️ nixos.qcow2 already exists..."

            export QEMU_NET_OPTS="hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:8008"
            export QEMU_OPTS
            ${vm}/bin/run-nixos-vm &
            PID=$!

            # Wait for the VM to start
            while ! curl -m 1 -s http://localhost:8080/;
            do
              if ! kill -0 $PID; then
                echo "❌ VM failed to start"
                exit 1
              fi
              sleep 1;
            done

            ${pkgs.python3}/bin/python -c 'import webbrowser; webbrowser.open("http://localhost:8080/")' &

            # Wait for the VM to exit
            wait $PID
          '';
        in
        {
          default = {
            type = "app";
            program = "${program}";
          };
        });

      devShells = perSystem (system:
        with pkgsFor system; {
          default = mkShell {
            nativeBuildInputs = [
              postgresql
              jq
              curl
              ipfs
              cardano-node.packages.${system}.cardano-cli
              arion.packages.${system}.arion
            ];
          };
          stage2 = cardano-transaction-lib.devShell.${system};
        });
    in
    {
      inherit apps nixosModules nixosConfigurations overlays devShells;
    };
}
