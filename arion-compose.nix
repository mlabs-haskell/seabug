{ pkgs, lib, config, ... }:

let
  inherit (config) share_dir nft-storage-key;
  inherit (pkgs.lib) mkOption;
  # The address of the marketplace script (`MarketPlace.js` in `seabug-contracts`)
  marketplace-escrow-address = "addr_test1wr05mmuhd3nvyjan9u4a7c76gj756am40qg7vuz90vnkjzczfulda";

  # FIXME: CTL version also pinned in seabug-contract. We need only one source of truth
in

{
  options = {
    share_dir = mkOption {
      default = "/var/lib/seabug";
    };

    nft-storage-key = mkOption {
      default = "NFT_STORAGE_KEY_HERE";
    };
  };

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
        # "${toString ./.}/nft-marketplace/build:/usr/share/nginx/html"
        "${pkgs.nft-marketplace-frontend-artifacts}:/usr/share/nginx/html"
        "${toString ./.}/config/nginx/nginx.conf:/etc/nginx/nginx.conf"
        "${toString ./.}/config/nginx/conf.d:/etc/nginx/conf.d"
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
        # [ "${pkgs.cardano-transaction-lib-server}/bin/cardano-browser-tx-server" ];
        [
          "${pkgs.cardano-transaction-lib-server}/bin/ctl-server"
          "--port"
          "8081"
          "--ogmios-host"
          "ogmios"
          "--ogmios-port"
          "1337"
        ];
      ports = [ "8081:8081" ];
      useHostStore = true;
      volumes = [
        "${share_dir}/data/cardano-node/ipc:/ipc"
      ];
      restart = "always";
    };

    ogmios.service = {
      command = [
        "--host"
        "0.0.0.0"
        "--node-socket"
        "/ipc/node.socket"
        "--node-config"
        "/config/testnet-node-config.json"
      ];
      depends_on = { cardano-node.condition = "service_healthy"; };
      image = "cardanosolutions/ogmios:v5.5.1-testnet";
      ports = [ "1337:1337" ];
      volumes = [
        "${share_dir}/data/cardano-node/ipc:/ipc"
        "${toString ./.}/config:/config"
      ];
      restart = "always";
    };

    ogmios-datum-cache.service = {
      command = [
        "${pkgs.ogmios-datum-cache}/bin/ogmios-datum-cache"
        "--db-connection"
        "host=postgresql-db port=5432 user=seabug dbname=seabug password=seabug"
        "--server-port"
        "9999"
        "--server-api"
        "usr:pwd"
        "--ogmios-address"
        "ogmios"
        "--ogmios-port"
        "1337"
        "--from-tip"
        "--use-latest"
        "--block-filter"
        # TODO: toJSON
        "{\"address\": \"${marketplace-escrow-address}\"}"
      ];
      depends_on = {
        ogmios.condition = "service_healthy";
        postgresql-db.condition = "service_healthy";
      };
      ports = [ "9999:9999" ];
      useHostStore = true;
      restart = "always";
    };

    cardano-node.service = {
      environment = { NETWORK = "testnet"; };
      image = "inputoutput/cardano-node:1.35.2";
      volumes = [
        "${share_dir}/data/cardano-node/ipc:/ipc"
        "${share_dir}/data/cardano-node/cardano-node-data:/data"
      ];
      healthcheck = {
        test = [
          "CMD-SHELL"
          "CARDANO_NODE_SOCKET_PATH=/ipc/node.socket /bin/cardano-cli query tip --testnet-magic 1097911063"
        ];
        interval = "10s";
        timeout = "5s";
        start_period = "120m";
        retries = 3;
      };
      restart = "always";
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
      volumes = [
        "${share_dir}/data/postgres-data:/var/lib/postgresql/data"
      ];
      restart = "always";
    };

    nft-marketplace-server.service = {
      image = "alpine";
      command = [
        "${pkgs.nft-marketplace-server}/bin/nft-marketplace-server"
        "--db-connection"
        "postgresql://seabug:seabug@postgresql-db:5432/seabug"
        "--nft-storage-key"
        nft-storage-key
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
      volumes = [
        "${share_dir}/config/tmp:/tmp"
      ];
    };

  };
}
