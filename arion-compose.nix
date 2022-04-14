{ pkgs, ... }:
let
  nft-marketplace-server =
    (pkgs.callPackage (import nft-marketplace-server/release.nix)
      { }).nft-marketplace-server;
  ogmios-datum-cache = (pkgs.callPackage (import ogmios-datum-cache/release.nix)
    { }).ogmios-datum-cache;
  cardano-transaction-lib-server = (import
    cardano-transaction-lib/default.nix).packages.x86_64-linux."ctl-server:exe:ctl-server";
in {
  # NOTE: still can't remember it...
  # ports = [ "host:container" ]
  config.services = {
    nft-marketplace.service = {
      build.context = "nft-marketplace/.";
      depends_on =
        [ "cardano-transaction-lib-server" "nft-marketplace-server" ];
      ports = [ "8080:80" ];
    };
    cardano-transaction-lib-server.service = {
      command = [ "${cardano-transaction-lib-server}/bin/ctl-server" ];
      ports = [ "8081:8081" ];
      useHostStore = true;
    };
    ogmios.service = {
      command = [
        "--host"
        "0.0.0.0"
        "--node-socket"
        "/ipc/node.socket"
        "--node-config"
        "/config/testnet-config.json"
      ];
      depends_on = [ "cardano-node" ];
      image = "cardanosolutions/ogmios:v5.2.0-testnet";
      ports = [ "1337:1337" ];
      volumes = [
        "${toString ./.}/data/cardano-node/ipc:/ipc"
        "${toString ./.}/config:/config"
      ];

    };
    ogmios-datum-cache.service = {
      command = [ "${ogmios-datum-cache}/bin/ogmios-datum-cache" ];
      depends_on = [ "ogmios" "postgresql-db" "nft-marketplace-server" ];
      ports = [ "9999:9999" ];
      useHostStore = true;
      volumes = [ "${toString ./.}/config:/config" ];
      working_dir = "/config";
      restart = "always";
    };
    cardano-node.service = {
      environment = { NETWORK = "testnet"; };
      image = "inputoutput/cardano-node:1.33.0";
      volumes = [
        "${toString ./.}/data/cardano-node/ipc:/ipc"
        "${toString ./.}/data/cardano-node/cardano-node-data:/data"
      ];
    };
    postgresql-db.service = {
      command = [ "-c" "stats_temp_directory=/tmp" ];
      environment = {
        POSTGRES_USER = "seabug";
        POSTGRES_PASSWORD = "seabug";
        POSTGRES_DB = "seabug";
      };
      image = "postgres:14";
      volumes =
        [ "${toString ./.}/data/postgres-data:/var/lib/postgresql/data" ];
    };
    nft-marketplace-server.service = {
      command = [
        "${nft-marketplace-server}/bin/nft-marketplace-server"
        "--db-connection"
        "postgresql://seabug:seabug@postgresql-db:5432/seabug"
        "--nft-storage-key"
        "NFT_STORAGE_KEY_HERE"
      ];
      depends_on = [ "postgresql-db" ];
      ports = [ "8008:9999" ];
      useHostStore = true;
      restart = "always";
    };
  };
}
