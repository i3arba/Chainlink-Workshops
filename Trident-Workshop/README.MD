# Hey! Hello again.

This is a simplifed version of [Trident](https://bellumgalaxy-trident.vercel.app). I removed most of security checks to make easier for rookies to interact with it.

## Chainlink Variables
Check the Chainlink documentation to get the address needed to run the `DeployScript.s.sol` and deploy the contracts. You can check it [here](https://docs.chain.link/chainlink-functions/supported-networks).

Create your subscription in this [link](https://functions.chain.link/). You will also need it to deploy the contract.

## Setup environment

To load it in your environment repeat the following steps:

Install the depencies by running:
```
forge build
```

Check the `remappings.toml`. It must have a remapping like this:
```
remappings = [
                "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
                "@chainlink/contracts/=lib/chainlink/contracts/"
             ]
```

Compile the project:
```
forge compile
```

Setup your encrypted wallet. Never let your private in plain text, even in test environments:
```
cast wallet import NameOfYourWallet --interactive
```

Follow the steps that forge you give you.

Update the `.env` file with an RPC url and API_KEY, if you want to verify your contract.

## Deploy

Once all is settled on the `DeployScript.s.sol`, run the following comand:
```
forge script script/DeployScript.s.sol --rpc-url $RPC_URL --account NAME_OF_YOUR_ENCRYPTED_WALLET --sender YOUR_PUBLIC_ADDRESS_IN_HERE --broadcast --verify --etherscan-api-key $API_KEY -vvvvv
```