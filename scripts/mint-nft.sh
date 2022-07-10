#!/bin/bash

# TODO: we don't need to restart nft_efficient_pab (early, it was required for
# request generation). Removing it can significantly speedup minting process

# TODO: we don't need passing arguments to the nft_efficient_pab. All real data
# passed via http, and right now we need it only for form nft mint request.

set -e

if [ $# != 5 ] && [ $# != 6 ]; then
	echo "Arguments: <IMAGE_FILE> <TITLE> <DESCRIPTION> <TOKEN_NAME> <MINT_POLICY> [<IPFS_CID>]"
	echo "  <MINT_POLICY> - arbitrary string"
	exit 1
fi

IMAGE=$1
TITLE=$2
DESC=$3
TOKEN_NAME=$4
export MINT_POLICY=$5
export IPFS_CID=$6

echo IMAGE: $IMAGE
echo TITLE: $TITLE
echo DESC: $DESC
echo TOKEN_NAME: $TOKEN_NAME
echo MINT_POLICY: $MINT_POLICY
echo IPFS_CID: $IPFS_CID

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
	CMD="unbuffer nix develop -c cabal run efficient-nft-pab --disable-optimisation --"
	ARGS="--pkh $PKH --auth-pkh $PKH --token \"$TOKEN_NAME\""
	if [ ! -z $CURRENCY ]; then
		ARGS="$ARGS --currency $CURRENCY"
	fi
	# if [ ! -z $MINT_POLICY ]; then
	# 	ARGS="$ARGS --mint-policy \"$MINT_POLICY\""
	# fi
	echo "> $CMD $ARGS | tee ../../$PAB_BUF"
	$CMD $ARGS | tee ../../$PAB_BUF
}

wait_up_efficient_nft_pab() {
	sleep 1
	echo '>' wait_up_efficient_nft_pab...
	while [ -z "$(rg 'Starting BotPlutusInterface server' $PAB_BUF)" ] && [ ! -z "$(jobs)" ]; do
		echo -n .
		sleep 1
	done
	sleep 3
	if [ ! -z "$(rg 'Network.Socket.bind: resource busy' $PAB_BUF)" ]; then
		echo "For some reason efficient_nft_pab already run, kill it"
		exit 1
	fi
	echo '>' wait_up_efficient_nft_pab...ok
}

mint_cnft_request() {
	http POST localhost:3003/api/contract/activate \
		caID[tag]=MintCnft \
		caID[contents][0]["mc'name"]="$TITLE" \
		caID[contents][0]["mc'description"]="$DESC" \
		caID[contents][0]["mc'image"]="ipfs://$IPFS_CID" \
		caID[contents][0]["mc'tokenName"]="$TOKEN_NAME_BASE64" -v
}

mint_request() {
	http POST 'localhost:3003/api/contract/activate' \
		caID[tag]=Mint \
		caID[contents][0][unAssetClass][0][unCurrencySymbol]="$CURRENCY" \
		caID[contents][0][unAssetClass][1][unTokenName]="$TOKEN_NAME" \
		caID[contents][1]["mp'mintPolicy"]="$MINT_POLICY" \
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
	while [ -z "$(rg BalanceTxResp $PAB_BUF)" ] && [ ! -z "$(jobs)" ]; do
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

if [ -z $IPFS_CID ]; then
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
	export IPFS_CID=$(ipfs cid format -b base36 $IPFS_HASH)
	echo '>' IPFS_CID: $IPFS_CID
fi

############################################################
# mint cnft
############################################################

echo '>>>' mint cnft

export PAB_BUF=efficient_nft_pab_out_1

echo '>' Run efficient-nft-pab...
efficient_nft_pab &
echo '>' If it stuck, check plutus-chain-index!
wait_up_efficient_nft_pab
echo '>' Run efficient-nft-pab...ok

echo '>' Run mint_cnft_request...
mint_cnft_request
wait_balance_tx_efficient_nft_pab
echo '>' Run mint_cnft_request...ok

kill_bg_jobs

BALANCE_TX_RESP=$(rg BalanceTxResp $PAB_BUF)
echo '>' BALANCE_TX_RESP: $BALANCE_TX_RESP

export CURRENCY=$(echo -n $BALANCE_TX_RESP | sed -E "s/^.*txMint = Value \(Map \[\(([^,]+).*/\1/")
echo '>' CURRENCY: $CURRENCY

UNAPPLIED_MINTING_POLICY=$(rg '^unapplied-minting-policy' $PAB_BUF | sed -e 's/unapplied-minting-policy: //' | jq -r)
echo '>' UNAPPLIED_MINTING_POLICY: $UNAPPLIED_MINTING_POLICY

query_utxo

echo '>' sleep 30 for minting work
sleep 30

query_utxo

############################################################
# mint nft
############################################################

echo '>>>' mint nft

export PAB_BUF=efficient_nft_pab_out_2

echo '>' Run efficient-nft-pab...
efficient_nft_pab &
wait_up_efficient_nft_pab
echo '>' Run efficient-nft-pab...ok

echo '>' Run mint_request...
mint_request
wait_balance_tx_efficient_nft_pab
echo '>' Run mint_request...ok

kill_bg_jobs

BALANCE_TX_RESP=$(rg BalanceTxResp $PAB_BUF)
echo '>' BALANCE_TX_RESP: $BALANCE_TX_RESP

query_utxo

echo '>' sleep 30 for minting work
sleep 30

query_utxo

echo '>' patch seabug_contracts/Seabug/MintingPolicy.js
sed -i "s/\".*\"/\"$UNAPPLIED_MINTING_POLICY\"/" seabug-contracts/src/Seabug/MintingPolicy.js

echo mint-nft ended
