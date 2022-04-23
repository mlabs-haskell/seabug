set -e
set -x
cd cardano-transaction-lib
npm run bundle-seabug
cd npm-packages/cardano-transaction-lib-seabug
npm install
cd ../../..
# This is a replacement of npm link. npm link is problematic on immutable file systems
rm nft-marketplace/node_modules/cardano-transaction-lib-seabug
ln -s $PWD/cardano-transaction-lib/npm-packages/cardano-transaction-lib-seabug\
      $PWD/nft-marketplace/node_modules/cardano-transaction-lib-seabug
cd nft-marketplace
cat <<EOT >> .env
SKIP_PREFLIGHT_CHECK=true
NODE_PATH=./src\

REACT_APP_API_BASE_URL=localhost:8008

REACT_APP_CTL_SERVER_HOST=localhost
REACT_APP_CTL_SERVER_PORT=8081
REACT_APP_CTL_SERVER_SECURE_CONN=false
REACT_APP_CTL_OGMIOS_HOST=localhost
REACT_APP_CTL_OGMIOS_PORT=1337
REACT_APP_CTL_OGMIOS_SECURE_CONN=false
REACT_APP_CTL_DATUM_CACHE_HOST=locahost
REACT_APP_CTL_DATUM_CACHE_PORT=9999
REACT_APP_CTL_DATUM_CACHE_SECURE_CONN=false
REACT_APP_CTL_NETWORK_ID=0
REACT_APP_CTL_PROJECT_ID=testnetu7qDM8q2XT1S6gEBSicUIqXB6QN60l7B

REACT_APP_IPFS_BASE_URL=https://cloudflare-ipfs.com/ipfs/
EOT
npm run build
