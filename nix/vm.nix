{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    ./seabug.nix
  ];

  system.stateVersion = "22.11";

  networking.hostName = "seabug";

  seabug.enable = true;

  virtualisation = {
    memorySize = 8192;
    diskSize = 100000;
    forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
      { from = "host"; host.port = 1337; guest.port = 1337; }
      { from = "host"; host.port = 8080; guest.port = 80; }
      { from = "host"; host.port = 8008; guest.port = 8008; }
    ];
  };

  # Easy debugging via console and ssh
  # WARNING: root access with empty password

  networking.firewall.enable = false;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  users.extraUsers.root.password = "";
  users.mutableUsers = false;

  environment.systemPackages = with pkgs; [
    python310Packages.httpie
    jq
    ripgrep
    ipfs
    (writeScriptBin "upload-image" (builtins.readFile ../scripts/upload-image.sh))
  ];

# environment.systemPackages = with pkgs; [
#     (writeShellApplication {
#       name = "upload-image";
#       text = builtins.readFile ../scripts/upload-image.sh;
#       runtimeInputs = [
#         ipfs
#         jq
#         python310Packages.httpie
#         ripgrep
#       ];
#     })
#   ];

}
