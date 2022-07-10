set -e
set -x

SEABUG=$PWD

cd $SEABUG/seabug-contracts
npm install
make run-build

cd $SEABUG/nft-marketplace
npm install

# This is a replacement of npm link. npm link is problematic on immutable file systems
rm -rf $SEABUG/nft-marketplace/node_modules/seabug-contracts
mkdir -p $SEABUG/nft-marketplace/node_modules/
ln -s $SEABUG/seabug-contracts \
      $SEABUG/nft-marketplace/node_modules/seabug-contracts

cd $SEABUG/nft-marketplace
rm -f .env
cat <<EOT >> .env
SKIP_PREFLIGHT_CHECK=true
NODE_PATH=./src

REACT_APP_API_BASE_URL=http://nft-mp-svr.localho.st:8080

REACT_APP_CTL_SERVER_HOST=ctl.localho.st
REACT_APP_CTL_SERVER_PORT=8080
REACT_APP_CTL_SERVER_SECURE_CONN=false

REACT_APP_CTL_OGMIOS_HOST=localho.st
REACT_APP_CTL_OGMIOS_PORT=1337
REACT_APP_CTL_OGMIOS_SECURE_CONN=false

REACT_APP_CTL_DATUM_CACHE_HOST=localho.st
REACT_APP_CTL_DATUM_CACHE_PORT=9999
REACT_APP_CTL_DATUM_CACHE_SECURE_CONN=false
REACT_APP_CTL_NETWORK_ID=0
REACT_APP_CTL_PROJECT_ID=testnetu7qDM8q2XT1S6gEBSicUIqXB6QN60l7B

REACT_APP_IPFS_BASE_URL=https://cloudflare-ipfs.com/ipfs/
EOT
npm run build
