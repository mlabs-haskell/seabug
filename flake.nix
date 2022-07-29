{
  description = "Seabug";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

    cardano-node.url = "github:input-output-hk/cardano-node/1.35.1";

    arion.url = github:hercules-ci/arion/bd3e2fe4e372d0b5f965f25f27c5eb7c1a618c4a;

    cardano-transaction-lib = {
      # url = github:Plutonomicon/cardano-transaction-lib/seabug-deployment;
      url = "github:Plutonomicon/cardano-transaction-lib/32194c502e4a068bf99388b05c708f81612d7541";
      # inputs.nixpkgs.follows = "nixpkgs"; # TODO: should we follow this?
    };

    nft-marketplace-frontend.url = github:mlabs-haskell/nft-marketplace/aciceri/nix; # TODO: change to master once this is merged: https://github.com/mlabs-haskell/nft-marketplace/pull/224

    nft-marketplace-server = {
      url = github:mlabs-haskell/nft-marketplace-server/3bcb7606b9172e17c9c70961ad1b083130430fee;
      # flake = false;
    };

    # nft-marketplace-server needs some specific versions.
    nixpkgs-nft-marketplace-server.url = github:nixos/nixpkgs/2cf9db0e3d45b9d00f16f2836cb1297bcadc475e;

    ogmios-datum-cache = {
      url = github:mlabs-haskell/ogmios-datum-cache/f8c671aebeb84d57b4879532073e20f8567c5ed4;
      # inputs.nixpkgs.follows = "nixpkgs"; # TODO: should we follow this?
      # flake = false;
    };

    seabug-contracts.url = "github:mlabs-haskell/seabug-contracts/23f49cf05d6230a8c1f63924ac9e61d1e1c0d5a8";
  };
  outputs =
    { self
    , nixpkgs
    , cardano-node
    , arion
    , nft-marketplace-frontend
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
          nft-marketplace-server = nft-marketplace-server.packages.${system}."nft-marketplace-server:exe:nft-marketplace-server";


          # TODO: system-agnostic
          inherit (inputs.ogmios-datum-cache.packages.${system}) ogmios-datum-cache;

          cardano-transaction-lib-server =
            # cardano-transaction-lib.packages.${system}."cardano-browser-tx-server:exe:cardano-browser-tx-server";
            cardano-transaction-lib.packages.${system}."ctl-server:exe:ctl-server";

          nft-marketplace-frontend-artifacts = nft-marketplace-frontend.packages.${system}.default;
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
                diskSize = 30000; # MB
                memorySize = 8196; # MB
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
          path = pkgs.lib.makeBinPath (with pkgs; [
            busybox
            curl
            openssh
            python3
            qemu
            sshpass
            vm
          ]);
          program = pkgs.writeShellScript "run-vm" ''
            set -euo pipefail
            # set -x

            export PATH=${pkgs.lib.escapeShellArg path}

            (![ -x nixos.qcow2 ] || echo "⚠️ nixos.qcow2 already exists...")

            export QEMU_NET_OPTS="hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:8080"
            export QEMU_OPTS="-serial stdio"
            run-nixos-vm &
            PID=$!

            # Wait for ssh port to open
            while ! (echo | telnet localhost:2221);
            do
              if ! kill -0 $PID; then
                echo "❌ VM failed to start"
                exit 1
              fi
              sleep 0.2;
            done

            # Show arion log
            sshpass -p toor \
              ssh root@127.0.0.1 -p 2221 \
              -o "UserKnownHostsFile=/dev/null" \
              -o "StrictHostKeyChecking=no" \
              journalctl -f -u arion-seabug.service &

            # Wait for the VM to start
            while ! curl -m 1 -s http://localhost:8080/;
            do
              if ! kill -0 $PID; then
                echo "❌ VM failed to start"
                exit 1
              fi
              sleep 1;
            done

            python -m webbrowser http://localhost:8080 &

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
