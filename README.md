MP1 Contracts  
Contracts and configs for Metaplayerone.app  
  
Setup:  
1. Install dependencies with `yarn install`
2. Rename `.env.sample` to `.env` and fill it in 
3. Compile the code with `truffle compile`

To deploy the contracts to the blockchain:  
1. Compile the code using `truffle compile`
2. Uncomment contracts to be deployed in `1_deploy_metaplayerone_contracts.js`
3. Set CONFIG in `.env` to `dev` for testnet and `prod` for mainnet deployment
4. run `truffle migrate --network <desired network>`

Contributing: see **CONTRIBUTING.md**
