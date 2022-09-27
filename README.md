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
- Funds in wallet obtained from [faucet](https://faucet.preview.world.dev.cardano.org/basic-faucet)

## Usage

### Clone repo

```shell
git clone --recurse-submodules git@github.com:mlabs-haskell/seabug.git
cd seabug
```

### Enter nix shell

```shell
nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```
From now, execute every command in the devshell created by the above command.

Note: if you run into a permission error when executing the above command, you may need to run `sudo chmod 777 -R /nix`, then run the above command again. Be aware that more restrictive file permissions may be safer.

### Setup `nft.storage` key

Replace `NFT_STORAGE_KEY_HERE` in `arion-compose.nix` with your key. You can obtain free API key from [nft.storage](https://nft.storage/).

### Optional: Copy testnet node database

If you have node db you can copy it to `data/cardano-node/cardano-node-data` to save hours on initial sync.
```shell
mkdir -p data/cardano-node/cardano-node-data
cp -r /path/to/old/db data/cardano-node/cardano-node-data/.
```

### Start services

```shell
./buildFrontend.sh
arion up
```

Please note that `arion up` will require a full cardano node to sync, which can take some time.  At time of writing (April, 2022), the current tip is at slot 56000000 and counting.

Once the chain is synced, you should be able to view the dApp UI from `localhost:8080`

Ensure that Nami is set to Preview, that you have some Test Ada (see [the faucet](https://faucet.preview.world.dev.cardano.org/basic-faucet)), and that you've set collateral in Nami.

### Optional: Mint your own NFTs

See the minting section in `seabug-contracts/README.md`. The following section describes how to upload an image and get its IPFS CID.

#### Upload NFT image

If you have an image:

``` shell
cd seabug
scripts/upload-image.sh
Arguments: <IMAGE_FILE> <TITLE> <DESCRIPTION>
scripts/upload-image.sh 'image.jpeg' 'Title' 'Description'
```

This will add the image to IPFS and the postgres database, and should print out something like:

```
IMAGE: image.jpeg
TITLE: Title
DESC: Description
> IMAGE_HASH: 4cefddfb4f62a3c68d08863cc299a2d6411174c8ff3325d21239ad3b5dcbf21c
> IPFS_HASH: bafkreicm57o7wt3cupdi2ceghtbjtiwwieixjsh7gms5eerzvu5v3s7sdq
> IPFS Base36 CID: k2cwueakfq42m0c5y33czg6ces3tj9b1xlv59krz88y2r8m18e2zxee4
```

The `IPFS Base36 CID` value can be used to continue the minting process.

## Maintenance

### Updating dependencies

- CTL: see [the docs](https://github.com/Plutonomicon/cardano-transaction-lib/blob/develop/doc/ctl-as-dependency.md)
- Submodules: assuming submodules have been setup locally ([see docs](https://git-scm.com/book/en/v2/Git-Tools-Submodules)), just change to the new commit in the submodule, then stage and commit in the main `seabug` repo.
- Purescript/JavaScript dependencies: these are managed in the submodules through the standard package management systems for the languages. For submodules using CTL (`seabug-contracts`), just be sure to follow the CTL docs to avoid conflicts in dependencies
- Haskell dependencies: managed in [nix flakes](https://nixos.wiki/wiki/Flakes)
- Runtime dependencies: also managed by flakes and [Arion](https://docs.hercules-ci.com/arion/)

### Targeting different networks

See [this PR](https://github.com/mlabs-haskell/seabug/pull/25) as an example of switching to the preview network. The general steps are:

- Update the [network in arion-compose.nix](https://github.com/mlabs-haskell/seabug/blob/68cdadfcd364076be467fe2dd2de4c06d35d4f3b/arion-compose.nix#L13-16)
- Make a blockfrost project pointing to the correct network, and update the blockfrost project ids throughout the project
- Update the network ids throughout the project
- Update the blockfrost api url in `seabug-contracts`

### Adding new off-chain contracts

See the [CTL docs](https://github.com/Plutonomicon/cardano-transaction-lib/tree/develop/doc). Off-chain contracts are stored in the `seabug-contracts` submodule.

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
