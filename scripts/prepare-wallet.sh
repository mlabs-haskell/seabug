#!/bin/bash

set -e
TESTNET_MAGIC=1097911063
WALLETS_DIR=data/wallets

mkdir -p $WALLETS_DIR

pushd $WALLETS_DIR
cardano-cli address key-gen --verification-key-file payment.vkey --signing-key-file payment.skey
cardano-cli address build --payment-verification-key-file payment.vkey --out-file payment.addr --testnet-magic $TESTNET_MAGIC

PKH=$(cardano-cli address key-hash --payment-verification-key-file payment.vkey)

mv payment.skey signing-key-$PKH.skey

ADDR=$(cat payment.addr)

mkdir $ADDR

mv payment.addr $ADDR/payment.addr
mv payment.vkey $ADDR/payment.vkey
mv signing-key-$PKH.skey $ADDR/signing-key-$PKH.skey

echo new wallet generated:
echo address: $ADDR
echo PKH: $PKH

popd

echo $WALLETS_DIR/$ADDR:
echo $(ls $WALLETS_DIR/$ADDR)
