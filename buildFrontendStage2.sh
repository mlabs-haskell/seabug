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
npm run build
