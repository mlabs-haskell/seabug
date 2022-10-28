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

  };

  config = lib.mkIf cfg.enable {
    nft-marketplace-frontend.enable = true;

    nft-marketplace-server = {
      enable = true;
      nftStorageKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6ZXRocjoweDc5OTNBMjY1NDg5NzE2RmMzMEY2RjFEZjlBOTY0NjM5ZEQzQzViZTAiLCJpc3MiOiJuZnQtc3RvcmFnZSIsImlhdCI6MTY2NTc0MjYxNjA5NywibmFtZSI6InNlYWJ1ZyJ9.2rGfgk3JT2_fBtouWu51dj0jQd3SrnI-NelLq-i5P_U";
    };

  };

}
