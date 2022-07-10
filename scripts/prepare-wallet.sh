#!/bin/bash

set -e
TESTNET_MAGIC=1097911063

cd plutus-use-cases/mlabs
cardano-cli address key-gen --verification-key-file payment.vkey --signing-key-file payment.skey
cardano-cli address build --payment-verification-key-file payment.vkey --out-file payment.addr --testnet-magic $TESTNET_MAGIC

PHK=$(cardano-cli address key-hash --payment-verification-key-file payment.vkey)

mkdir -p pab/signing-keys
mv payment.skey pab/signing-keys/signing-key-$PHK.skey

echo new wallet generated:
echo address: $(cat payment.addr)
echo PHK: $PHK

echo file: $(ls payment.addr)
echo file: $(ls payment.vkey)
echo file: $(ls pab/signing-keys/signing-key-$PHK.skey)
