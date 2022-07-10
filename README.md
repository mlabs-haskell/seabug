# Seabug

- [Prerequisites](#prerequisites)
- [Usage](#usage)
  * [Clone repo](#clone-repo)
  * [Enter nix shell](#enter-nix-shell)
  * [Setup `nft.storage` key](#setup--nftstorage--key)
  * [Optional: Copy testnet node database](#optional--copy-testnet-node-database)
  * [Start services](#start-services)
  * [Optional: Mint your own NFTs](#optional--mint-your-own-nfts)
- [Components](#components)
  * [`nft-marketplace`](#-nft-marketplace-)
  * [`ogmios-datum-cache`](#-ogmios-datum-cache-)
  * [`ogmios`](#-ogmios-)
  * [`postgresql`](#-postgresql-)
  * [`nft-marketplace-server`](#-nft-marketplace-server-)
  * [`cardano-transaction-lib-server`](#-cardano-transaction-lib-server-)
  * [`cardano-node`](#-cardano-node-)
  * [Onchain SmartContracts](#onchain-smartcontracts)

## Prerequisites

- nix
- [IOHK binary cache](https://github.com/input-output-hk/plutus#how-to-set-up-the-iohk-binary-caches)
- arion - Provided by devshell
- [docker](https://docs.docker.com/get-docker/)
- [nami wallet](https://namiwallet.io/) installed as browser extension
- Funds in wallet obtained from [faucet](https://testnets.cardano.org/en/testnets/cardano/tools/faucet/)

## Usage

### Clone repo

```shell
$ git clone --recurse-submodules git@github.com:mlabs-haskell/seabug.git
```

### Enter nix shell

```shell
$ nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```
From now, execute every command in devshell dropped by `nix develop`

### Setup `nft.storage` key

Replace `NFT_STORAGE_KEY_HERE` in `arion-compose.nix` with your key. You can obtain free API key from [nft.storage](https://nft.storage/).

### Optional: Copy testnet node database

If you have node db you can copy it to `data/cardano-node/cardano-node-data` to save hours on initial sync.
```shell
$ mkdir -p data/cardano-node/cardano-node-data
$ cp -r /path/to/old/db data/cardano-node/cardano-node-data/.
```

### Start services

```shell
$ ./buildFrontend.sh
$ arion up
```

Please note that `arion up` will require a full cardano node to sync, which can take some time.  At time of writing (April, 2022), the current tip is at slot 56000000 and counting.

Once the chain is synced, you should be able to view the dApp UI from `localhost:8080`

Ensure that Nami is set to Testnet, that you have some Test Ada, and that you've set collateral in Nami.

### Optional: Mint your own NFTs

#### Start plutus-chain-index 

Set environment variables:

``` shell
$ pwd
.../seabug
$ export CARDANO_NODE_SOCKET_PATH=$PWD/data/cardano-node/ipc/node.socket
$ mkdir -p chain-index
$ export CHAIN_INDEX_PATH=$PWD/chain-index/chain-index.sqlite
```

Fix permission problem for `node.socket` (if you receive error like: `plutus-chain-index: Network.Socket.connect: <socket: 35>: permission denied (Permission denied)`):

``` shell
$ sudo chmod 0666 $CARDANO_NODE_SOCKET_PATH
```

Building and run plutus-chain-index from the source:

```
$ cd ..
$ git clone git@github.com:input-output-hk/plutus-apps.git 
$ cd plutus-apps
$ nix build -f default.nix plutus-chain-index
$ result/bin/plutus-chain-index start-index --network-id 1097911063 --db-path $CHAIN_INDEX_PATH/chain-index.sqlite --socket-path $CARDANO_NODE_SOCKET_PATH
```

The index should be synced for minting. 

#### Prepare wallet

``` shell
$ cd seabug
$ nix develop
$ scripts/prepare-wallet.sh
new wallet generated:
address: addr_test1vp3tywa08qjjj7mplzmwjs9kmes0ce3ud5da3x0wppu5e9qgxqhps
PHK: 62b23baf3825297b61f8b6e940b6de60fc663c6d1bd899ee08794c94
file: payment.addr
file: payment.vkey
file: pab/signing-keys/signing-key-62b23baf3825297b61f8b6e940b6de60fc663c6d1bd899ee08794c94.skey
```

Add some Ada to your wallet:
- by Nami wallet
- or by [Faucet](https://testnets.cardano.org/en/testnets/cardano/tools/faucet/)
  
Check the result:
  
```shell
$ cd seabug
$ cardano-cli query utxo --testnet-magic 1097911063 --address $(cat payment.addr)
                           TxHash                                 TxIx        Amount
--------------------------------------------------------------------------------------
ed11c8765d764852d049cd1a2239524ade0c6057a3a51146dc8c9d7bcbe008e0     0        100000000 lovelace + TxOutDatumNone
```

#### Mint your own NFT

If you have an image:

``` shell
$ cd seabug
$ scripts/mint-nft.sh
Arguments: <IMAGE_FILE> <TITLE> <DESCRIPTION> <TOKEN_NAME> <MINT_POLICY> [<IPFS_CID>]
  <MINT_POLICY> - arbitrary string to identify mint policy
$ scripts/mint-nft.sh 'image.jpeg' 'Title' 'Description' 'Token name' 'mintPolicy' 
```

The script take some time to work, especially if you haven't used efficient_nft_pab before (`cd plutus-use-cases/mlabs && nix develop -c cabal run efficient-nft-pab --disable-optimisation`). 

If you already uploaded the image to nft.storage and have IPFC_CID (you can get it from nft.storage web interface).

``` shell
$ cd seabug
$ scripts/mint-nft.sh 'image.jpeg' 'Title' 'Description' 'Token name' 'mintPolicy' k2cwueaf1ew3nr2gq2rw83y13m2f5jpg8uyymn66kr8ogeglrwcou5u8
```

## Components

### `nft-marketplace`

Frontend for Seabug marketplace, interacts with Cardano blockchain using `cardano-transaction-lib`.

### `seabug-contract`

NFT marketplace contracts in purescript. Onchain part was hardcoded as binary.

### `ogmios-datum-cache`

Caches datums of NFTs that are on available marketplace.

### `ogmios`

A lightweight interface for `cardano-node`. Used for `cardano-transaction-lib` and `ogmios-datum-cache` to interact with blockchain.

### `postgresql`

Database used to store images data (in addition to IPFS), artists data and datums stored by `ogmios-datum-cache`.

### `nft-marketplace-server`

Backend server used for storing storing image and artists data and uploading artworks to IPFS node.

### `cardano-transaction-lib-server`

A small server used to provide services to the `cardano-transaction-lib` frontend that cannot be achieved using Purescript.

### `cardano-node`

Relay node of Cardano blockchain.

### Onchain SmartContracts

- [Minting policy](https://github.com/mlabs-haskell/plutus-use-cases/blob/927eade6aa9ad37bf2e9acaf8a14ae2fc304b5ba/mlabs/src/Mlabs/EfficientNFT/Token.hs)
- [Locking script](https://github.com/mlabs-haskell/plutus-use-cases/blob/927eade6aa9ad37bf2e9acaf8a14ae2fc304b5ba/mlabs/src/Mlabs/EfficientNFT/Lock.hs)
- [Marketplace script](https://github.com/mlabs-haskell/plutus-use-cases/blob/927eade6aa9ad37bf2e9acaf8a14ae2fc304b5ba/mlabs/src/Mlabs/EfficientNFT/Marketplace.hs)
- [Fee collecting script](https://github.com/mlabs-haskell/plutus-use-cases/blob/927eade6aa9ad37bf2e9acaf8a14ae2fc304b5ba/mlabs/src/Mlabs/EfficientNFT/Dao.hs)
