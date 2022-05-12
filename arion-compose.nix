{ pkgs, ... }:

{
  # NOTE: still can't remember it...
  # ports = [ "host:container" ]
  config.services = {
    nft-marketplace.service = {
      depends_on = {
        nft-marketplace-server.condition = "service_healthy";
        ogmios.condition = "service_healthy";
        # TODO: Change to `service_healthy` when healthcheck endpoints are implemented
        cardano-transaction-lib-server.condition = "service_started";
        ogmios-datum-cache.condition = "service_started";
      };
      image = "nginx:1.20.2-alpine";
      ports = [ "8080:80" ];
      volumes = [
        "${toString ./.}/nft-marketplace/build:/usr/share/nginx/html"
        "${toString ./.}/config/nginx.conf:/etc/nginx/nginx.conf"
      ];
      healthcheck = {
        test = [
          "CMD"
          "${pkgs.curl}/bin/curl"
          "--location"
          "--request"
          "GET"
          "nft-marketplace"
          "-i"
          "--fail"
        ];
        interval = "5s";
        timeout = "5s";
        retries = 3;
      };
      useHostStore = true;
    };
    cardano-transaction-lib-server.service = {
      command =
        [ "${pkgs.cardano-transaction-lib-server}/bin/cardano-browser-tx-server" ];
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
      depends_on = { cardano-node.condition = "service_healthy"; };
      image = "cardanosolutions/ogmios:v5.2.0-testnet";
      ports = [ "1337:1337" ];
      volumes = [
        "${toString ./.}/data/cardano-node/ipc:/ipc"
        "${toString ./.}/config:/config"
      ];
    };
    ogmios-datum-cache.service = {
      command = [ "${pkgs.ogmios-datum-cache}/bin/ogmios-datum-cache" ];
      depends_on = {
        ogmios.condition = "service_healthy";
        postgresql-db.condition = "service_healthy";
      };
      ports = [ "9999:9999" ];
      useHostStore = true;
      volumes = [
        "${toString ./.}/config/datum-cache-config.toml:/config/config.toml"
      ];
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
      healthcheck = {
        test = [
          "CMD-SHELL"
          "CARDANO_NODE_SOCKET_PATH=/ipc/node.socket /bin/cardano-cli query tip --testnet-magic 1097911063"
        ];
        interval = "10s";
        timeout = "5s";
        start_period = "15m";
        retries = 3;
      };
    };
    postgresql-db.service = {
      command = [ "-c" "stats_temp_directory=/tmp" ];
      environment = {
        POSTGRES_USER = "seabug";
        POSTGRES_PASSWORD = "seabug";
        POSTGRES_DB = "seabug";
      };
      image = "postgres:14";
      ports = [ "5432:5432" ];
      healthcheck = {
        test = [ "CMD" "pg_isready" "-U" "seabug" ];
        interval = "5s";
        timeout = "5s";
        retries = 3;
      };
      volumes =
        [ "${toString ./.}/data/postgres-data:/var/lib/postgresql/data" ];
    };
    nft-marketplace-server.service = {
      command = [
        "${pkgs.nft-marketplace-server}/bin/nft-marketplace-server"
        "--db-connection"
        "postgresql://seabug:seabug@postgresql-db:5432/seabug"
        "--nft-storage-key"
        "NFT_STORAGE_KEY_HERE"
      ];
      depends_on = { postgresql-db.condition = "service_healthy"; };
      ports = [ "8008:9999" ];
      healthcheck = {
        test = [
          "CMD"
          "${pkgs.curl}/bin/curl"
          "--location"
          "--request"
          "GET"
          "nft-marketplace-server:9999/healthz"
          "-i"
          "--fail"
        ];
        interval = "5s";
        timeout = "5s";
        retries = 3;
      };
      useHostStore = true;
      restart = "always";
      volumes = [ "${toString ./.}/config/tmp:/tmp" ];
    };
  };
}
