{ cardano-cli, plutus-use-cases, pkgs, ... }:

pkgs.writeShellApplication {
  name = "prepare-wallet";
  runtimeInputs = [ cardano-cli ];
  text = ''
    TESTNET_MAGIC=2

    out_dir=$(pwd)/pab/signing_keys
    mkdir -p "$out_dir"

    pushd "${plutus-use-cases}/mlabs" > /dev/null

    cardano-cli address key-gen --verification-key-file "$out_dir/payment.vkey" --signing-key-file "$out_dir/payment.skey"
    cardano-cli address build --payment-verification-key-file "$out_dir/payment.vkey" --out-file "$out_dir/payment.addr" --testnet-magic $TESTNET_MAGIC

    PHK=$(cardano-cli address key-hash --payment-verification-key-file "$out_dir/payment.vkey")

    echo "$PHK"
    echo "Populated $out_dir"

    popd > /dev/null
  '';
}
