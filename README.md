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
- arion - Use patched one from `nix develop`!
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

This process will be simplified in the future.

```shell
$ # Setup server admin token, password: seabug
$ PGPASSWORD=seabug psql -U seabug -h localhost -c "INSERT INTO admin_token(token) VALUES ('ADMIN_TOKEN')"

$ # Upload image
$ curl --location --request POST "locahost:8008" \
    -F "image=@./cat123.png" \
    -F "title=Cat Cat number 123" \
    -F "description=Cat eating piece of cheese" \
    -H "Authorization: ADMIN_TOKEN"

$ # Get IPFS CID, replace SHA_256_HASH with hash from previous response, note "ipfsHash"
$ curl --location --request GET 'localhost:8008' \
    | jq 'to_entries[] | select (.value.sha256hash=="SHA_256_HASH")'

$ # Convert CID, replace "IPFS_HASH" with hash from previous response, note the result
$ ipfs cid format -b=base36 IPFS_HASH

$ # Configure keys for BPI
$ cd plutus-use-cases/mlabs
$ cardano-cli address build \
    --payment-verification-key-file payment.vkey \ 
    --out-file payment.addr \ 
    --testnet-magic 1097911063
$ cardano-cli address key-gen \
    --verification-key-file payment.vkey \
    --signing-key-file payment.skey
$ mkdir -p pab/signing-keys
$ cat payment.addr
$ mv payment.skey pab/signing-keys/signing-key-PKH_HERE.skey

$ # Start BPI, note "minting-policy", it will be used later
$ nix develop -L -c cabal run efficient-nft-pab

$ # In other console
$ # Mint underlying CNFTs, replace "CONVERTED_CID" with the result of `ipfs` command
$ curl --location --request POST 'localhost:3003/api/contract/activate' \
    --header 'Content-Type: application/json' \
    --data-raw '
     {
        "caID": {
            "tag":"MintCnft",
            "contents":[
               {
                  "mc'"'"'name":"Cat number 123",
                  "mc'"'"'description":"Cat eating piece of cheese",
                  "mc'"'"'image":"ipfs://CONVERTED_CID",
                  "mc'"'"'tokenName":"cat-123" # This should be hex encoded (without 0x)
               }
            ]
        }
     }'

$ # Go back to previous terminal and stop BPI
$ # Replace "CURRENCY_SYMBOL" in /efficient-nft-pab/Main.hs with currency symbol from BPI log
$ # Restart BPI, note "seabug-mint-request"
$ nix develop -L -c cabal run efficient-nft-pab

$ # Mint SeaBug NFT
$ curl --location --request POST 'localhost:3003/api/contract/activate'
    --header 'Content-Type: application/json' \
    --data-raw 'INSERT_seabug-mint-request_HERE'

$ cd ../cardano-transaction-lib
$ # Replace value of "mintingPolicy1" in seabug_contracts/MintingPolicy.js with policy noted from BPI
```

## Components

### `nft-marketplace`

Frontend for Seabug marketplace, interacts with Cardano blockchain using `cardano-transaction-lib`.

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
