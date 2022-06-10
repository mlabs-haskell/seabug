#!/bin/bash

set -e

if [ $# != 4 ] && [ $# != 5 ]; then
	echo "Arguments: <IMAGE_FILE> <TITLE> <DESCRIPTION> <TOKEN_NAME> [<IPFC_CID>]"
	exit 1
fi

IMAGE=$1
TITLE=$2
DESC=$3
TOKEN_NAME=$4
IPFC_CID=$5

echo IMAGE: $IMAGE
echo TITLE: $TITLE
echo DESC: $DESC
echo TOKEN_NAME: $TOKEN_NAME
echo IPFC_CID: $IPFC_CID

TOKEN_NAME_BASE64=$(echo -n $TOKEN_NAME | od -A n -t x1 | tr -d " \n")
echo TOKEN_NAME_BASE64: $TOKEN_NAME_BASE64

PKH=$(cardano-cli address key-hash --payment-verification-key-file plutus-use-cases/mlabs/payment.vkey)
echo PKH: $PKH

# enviroment variables
SEABUG_ADMIN_TOKEN=ADMIN_TOKEN
TESTNET_MAGIC=1097911063
export PGPASSWORD=seabug
export CARDANO_NODE_SOCKET_PATH=$PWD/data/cardano-node/ipc/node.socket

############################################################
# Prepare
############################################################

# Setup server admin token, password: seabug
psql -U seabug -h localhost -q -c "INSERT INTO admin_token(token) VALUES ('$SEABUG_ADMIN_TOKEN') ON CONFLICT DO NOTHING"

############################################################
# Functions
############################################################

get_ipfs_hash() {
	local IMAGE_HASH=$1
	http GET localhost:8008/images |
		jq -r "to_entries[] | select (.value.sha256hash == \"$IMAGE_HASH\") | .value.ipfsHash"
}

efficient_nft_pab() {
	cd plutus-use-cases/mlabs
	rm -fv ../../efficient_nft_pab_out
	if [ -z $CURRENCY ]; then
		echo "> unbuffer nix develop -c cabal run efficient-nft-pab --disable-optimisation -- --pkh $PKH --auth-pkh $PKH --token \"$TOKEN_NAME\" | tee ../../efficient_nft_pab_out"
		unbuffer nix develop -c cabal run efficient-nft-pab --disable-optimisation -- --pkh $PKH --auth-pkh $PKH --token "$TOKEN_NAME" >../../efficient_nft_pab_out
	else
		echo "> unbuffer nix develop -c cabal run efficient-nft-pab --disable-optimisation -- --pkh $PKH --auth-pkh $PKH --token "$TOKEN_NAME" --currency $CURRENCY | tee ../../efficient_nft_pab_out"
		unbuffer nix develop -c cabal run efficient-nft-pab --disable-optimisation -- --pkh $PKH --auth-pkh $PKH --token "$TOKEN_NAME" --currency $CURRENCY >../../efficient_nft_pab_out
	fi
}

wait_up_efficient_nft_pab() {
	sleep 1
	echo '>' wait_up_efficient_nft_pab...
	while [ -z "$(rg 'Starting BotPlutusInterface server' efficient_nft_pab_out)" ] && [ ! -z "$(jobs)" ]; do
		echo -n .
		sleep 1
	done
	sleep 3
	if [ ! -z "$(rg 'Network.Socket.bind: resource busy' efficient_nft_pab_out)" ]; then
		echo "For some reason efficient_nft_pab already run, kill it"
		exit 1
	fi
	echo '>' wait_up_efficient_nft_pab...ok
}

mint_cnft_request() {
	local IPFC_CID=$1
	http POST localhost:3003/api/contract/activate \
		caID[tag]=MintCnft \
		caID[contents][0]["mc'name"]="$TITLE" \
		caID[contents][0]["mc'description"]="$DESC" \
		caID[contents][0]["mc'image"]="ipfs://$IPFC_CID" \
		caID[contents][0]["mc'tokenName"]="$TOKEN_NAME_BASE64" -v
}

mint_request() {
	http POST 'localhost:3003/api/contract/activate' \
		caID[tag]=Mint \
		caID[contents][0][unAssetClass][0][unCurrencySymbol]="$CURRENCY" \
		caID[contents][0][unAssetClass][1][unTokenName]="$TOKEN_NAME" \
		caID[contents][1]["mp'fakeAuthor"][unPaymentPubKeyHash][getPubKeyHash]="$PKH" \
		caID[contents][1]["mp'feeVaultKeys"]:=[] \
		caID[contents][1]["mp'price"]:=100000000 \
		caID[contents][1]["mp'daoShare"]:=500 \
		caID[contents][1]["mp'owner"][0][unPaymentPubKeyHash][getPubKeyHash]="$PKH" \
		caID[contents][1]["mp'owner"][1]:=null \
		caID[contents][1]["mp'lockLockupEnd"][getSlot]:=5 \
		caID[contents][1]["mp'authorShare"]:=1000 \
		caID[contents][1]["mp'lockLockup"]:=5 -v
}

wait_balance_tx_efficient_nft_pab() {
	echo '>' wait_balance_tx_efficient_nft_pab...
	while [ -z "$(rg BalanceTxResp efficient_nft_pab_out)" ] && [ ! -z "$(jobs)" ]; do
		echo -n .
		sleep 1
	done
	echo '>' wait_balance_tx_efficient_nft_pab...ok
}

kill_bg_jobs() {
	echo '>' kill bg jobs...
	sleep 5
	killall efficient-nft-p
	kill $(jobs -p)
	while [ ! -z $(jobs -p) ]; do
		sleep 1
		echo -n .
	done
	echo '>' kill bg jobs...ok
}

query_utxo() {
	cardano-cli query utxo --testnet-magic $TESTNET_MAGIC --address $(cat plutus-use-cases/mlabs/payment.addr)
}

############################################################
# upload image
############################################################

query_utxo

if [ -z $IPFC_CID ]; then
	echo '>' Image upload...
	BUF=$(
		http --form POST localhost:8008/admin/upload_image \
			"Authorization:$SEABUG_ADMIN_TOKEN" \
			"files@$IMAGE" \
			"title=$TITLE" \
			"description=$DESC" \
			--pretty none
	)
	IMAGE_HASH=$(echo -n "$BUF" | rg '^\{' | jq -r '.sha256hash')
	if [ -z "$IMAGE_HASH" ] || [ "$IMAGE_HASH" = "null" ]; then
		echo Upload image error: $BUF
		exit 1
	fi
	echo '>' Image upload...ok
	echo '>' IMAGE_HASH: $IMAGE_HASH
	IPFS_HASH=$(get_ipfs_hash $IMAGE_HASH)
	echo '>' IPFS_HASH: $IPFS_HASH
	IPFS_CID=$(ipfs cid format -b base36 $IPFS_HASH)
	echo '>' IPFS_CID: $IPFS_CID
fi

############################################################
# mint cnft
############################################################

echo '>>>' mint cnft

echo '>' Run efficient-nft-pab...
efficient_nft_pab &
wait_up_efficient_nft_pab
echo '>' Run efficient-nft-pab...ok

echo '>' Run mint_cnft_request...
mint_cnft_request $IPFC_CID
wait_balance_tx_efficient_nft_pab
echo '>' Run mint_cnft_request...ok

kill_bg_jobs

BALANCE_TX_RESP=$(cat efficient_nft_pab_out | rg BalanceTxResp)
echo '>' BALANCE_TX_RESP: $BALANCE_TX_RESP

export CURRENCY=$(echo -n $BALANCE_TX_RESP | sed -E "s/^.*txMint = Value \(Map \[\(([^,]+).*/\1/")
echo '>' CURRENCY: $CURRENCY

query_utxo

echo '>' sleep 30 for minting work
sleep 30

query_utxo

############################################################
# mint nft
############################################################

echo '>>>' mint nft

cp -v efficient_nft_pab_out efficient_nft_pab_out0

echo '>' Run efficient-nft-pab...
efficient_nft_pab &
wait_up_efficient_nft_pab
echo '>' Run efficient-nft-pab...ok

echo '>' Run mint_request...
mint_request
wait_balance_tx_efficient_nft_pab
echo '>' Run mint_request...ok

kill_bg_jobs

BALANCE_TX_RESP=$(cat efficient_nft_pab_out | rg BalanceTxResp)
echo '>' BALANCE_TX_RESP: $BALANCE_TX_RESP

MINTING_POLICY=$(cat efficient_nft_pab_out | rg minting-policy | sed -e 's/minting-policy: //' | jq -r .getMintingPolicy)
echo '>' MINTING_POLICY: $MINTING_POLICY

echo '>' patch seabug_contracts/Seabug/MintingPolicy.js
sed -i "3s/\".*\"/\"$MINTING_POLICY\"/" cardano-transaction-lib/seabug_contracts/Seabug/MintingPolicy.js

query_utxo

echo '>' sleep 30 for minting work
sleep 30

query_utxo

echo mint-nft ended
