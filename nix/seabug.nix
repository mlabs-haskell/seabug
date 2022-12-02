{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.seabug;
in
{
  options.seabug = {

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    frontend-maker = lib.mkOption {
      type = with lib.types; functionTo package;
    };

    frontend = lib.mkOption {
      type = lib.types.package;
      default = with cfg; (frontend-maker
        {
          REACT_APP_API_BASE_URL = api.baseUrl;
          REACT_APP_CTL_LOG_LEVEL = ctl.logLevel;
          REACT_APP_CTL_SERVER_HOST = ctl.server.host;
          REACT_APP_CTL_SERVER_PORT = "${toString ctl.server.port}";
          REACT_APP_CTL_SERVER_SECURE_CONN = "${lib.boolToString ctl.server.secureConnection}";
          REACT_APP_CTL_OGMIOS_HOST = ctl.ogmios.host;
          REACT_APP_CTL_OGMIOS_PORT = ctl.ogmios.port;
          REACT_APP_CTL_OGMIOS_SECURE_CONN = "${lib.boolToString ctl.ogmios.secureConnection}";
          REACT_APP_CTL_DATUM_CACHE_HOST = ctl.ogmios-datum-cache.host;
          REACT_APP_CTL_DATUM_CACHE_PORT = "${toString ctl.ogmios-datum-cache.port}";
          REACT_APP_CTL_DATUM_CACHE_SECURE_CONN = "${lib.boolToString ctl.ogmios-datum-cache.secureConnection}";
          REACT_APP_CTL_NETWORK_ID = "${toString ctl.networkId}";
          REACT_APP_CTL_PROJECT_ID = ctl.projectId;
          REACT_APP_IPFS_BASE_URL = ipfsBaseUrl;
        } // buildExtraSettings);
    };

    api.baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://api.seabug.staging.mlabs.city";
    };

    ctl = {
      logLevel = lib.mkOption {
        type = lib.types.str;
        default = "Trace";
      };

      server = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "ctl-server.preview-seabug.ctl-runtime.staging.mlabs.city";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 443;
        };

        secureConnection = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };

      ogmios = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "ogmios.preview-seabug.ctl-runtime.staging.mlabs.city";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 443;
        };

        secureConnection = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };

      ogmios-datum-cache = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "ogmios-datum-cache.preview-seabug.ctl-runtime.staging.mlabs.city";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 443;
        };

        secureConnection = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };

      networkId = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };

      projectId = lib.mkOption {
        type = lib.types.str;
        default = "previewoXa2yw1U0z39X4VmTs6hstw4c6cPx1LN";
      };
    };

    ipfsBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cloudflare-ipfs.com/ipfs/";
    };

    buildExtraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };

    virtualHostName = lib.mkOption {
      type = lib.types.str;
      default = "seabug";
    };

  };

  config = lib.mkIf cfg.enable {
    services.nft-marketplace-server = {
      enable = true;
      nftStorageKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6ZXRocjoweDc5OTNBMjY1NDg5NzE2RmMzMEY2RjFEZjlBOTY0NjM5ZEQzQzViZTAiLCJpc3MiOiJuZnQtc3RvcmFnZSIsImlhdCI6MTY2NTc0MjYxNjA5NywibmFtZSI6InNlYWJ1ZyJ9.2rGfgk3JT2_fBtouWu51dj0jQd3SrnI-NelLq-i5P_U";
    };

    services.nginx = {
      commonHttpConfig = ''
        types {
            application/wasm wasm;
        }
      '';
      virtualHosts = {
        "seabug-frontend" = {
          locations."/" ={
            root = "${cfg.frontend}";
            tryFiles = "$uri $uri/ /index.html =404";
            index = "index.html index.htm";
          };
        };
        "seabug-backend" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.nft-marketplace-server.port}";
          };
        };
      };
    };

  };

}
