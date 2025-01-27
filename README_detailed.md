# Long Version - Fairblock Precompiles on EVMs Showcasing Orbit Chains

This is the detailed version of the ["Decryption Contracts on EVMs with Orbit Chains" Quickstart](./README.md). It will typically take longer than going through the quickstart, but you will cover extra details including:

- What pre-compiles will go into `contracts.go` and extra dependencies to add to the `nitro` code
- Setting up your own Orbit chain following the Arbitrum Orbit documentation

> ‼️ All code within this tutorial is purely educational, and it is up to the readers discretion to build their applications following industry standards, practices, and applicable regulations.

Let's get into it.

The key checkpoints for this tutorial are:

1. Setup a custom EVM w/ precompiles and compile the docker image.
2. Deploy the base contracts for a new orbit chain and register it on the Arbitrum Sepolia Testnet.
3. Use newly obtained config files to update your local orbit chain codebase. This will ensure you are communicating with it properly in your local environment.
4. Run your docker image for the orbit chain configured to the custom nitro nodes such that it is persistent and can be interacted with whilst your local environment is setup.
5. Finish setting up your local instance by funding the batch-poster and validator (staker) accounts for your underlying L2 chain. 
6. Create a script that setups your docker images within a local container.
7. Deploy and test a Sealed Bid Auction smart contract, written in Solidity, working with the newly integrated precompile logic.
  - The underlying contracts and scripts will provide developers a sense of the integration process with the Orbit chain pre-compile logic and ultimately Fairblock's testnet, Fairyring.

Once you have gone through this quickstart, you will have a basic understanding of how to modify your own custom EVM chain to be able to work with Fairyring and its functionalities. 

# Setup and Deploy Arbitrum Orbit Custom Chain Locally

This quickstart starts with setting up the new local Orbit testnet that will eventually have encryption, and conditional decryption and execution functionality within it. 

For those new to Arbitrum technologies, here are the main pre-requisite knowledge to understand the tutorial:

- Arbitrum Orbit (Orbit) is a framework to create L2s or L3s with many different configurations.
- By default, it settles onto the Arbitrum One L2, and thus leverages the security of Ethereum Mainnet.
- New Orbit chains are deployed with initial registration on the respective settlement layer, typically Arbitrum One, but can be Nova or other settlement layers.

## 1. Modify `geth` and Compile It

To start, you will clone the nitro tech stack from Arbitrum, adjust dependencies as needed, and modify the geth file `contracts.go`. This file contains the core logic pertaining to operations within the Arbitrum Orbit Chain's EVM.

### a. Clone the nitro repository, Adjust gitmodules, and Add New Dependencies

```shell
git clone https://github.com/Layr-Labs/nitro.git
cd nitro
git submodule update --init --recursive --force
```

Modify the `.gitmodules`, as seen below, to have the `go-ethereum` submodule point to the non-private nitro-go-ethereum url.

```text
[submodule "go-ethereum"]
        path = go-ethereum
-       url = git@github.com:Layr-Labs/nitro-go-ethereum-private.git
+       url = https://github.com/Layr-Labs/nitro-go-ethereum.git
        branch = eigenda-v3.1.2
```

Next, add dependencies needed for the pre-compile functionality that you will be adding to your custom EVM chain.

```bash
go get github.com/FairBlock/DistributedIBE/encryption

go get github.com/drand/kyber-bls12381
```

Now update and sync the repo to respect these changes by running the following CLI commands:

```shell
git submodule sync
git submodule update --init --recursive --force
```

### b. Modify the Code with Pre-Compile Functionalities

The next step is to add in the pre-compile changes. This will be done by modifying the `contracts.go` file that should be found in your copy of the repo. Here you can see where it is found within the remote repo's directories: [nitro-go-ethereum/core/vm/contracts.go](https://github.com/Layr-Labs/nitro-go-ethereum/blob/5a2943c/core/vm/contracts.go) file.

* Add in the necessary imports for the encrypted package.

```go
import (
   "bytes"
   enc "github.com/FairBlock/DistributedIBE/encryption"
   bls "github.com/drand/kyber-bls12381"
)
```

* Add the `decrypt()` function to the file by simply copying and pasting the below at the bottom of the file.

```go
func decrypt(input []byte) ([]byte, error) {

 privateKeyByte := input[0:96]

 cipherBytes := input[96:]

 suite := bls.NewBLS12381Suite()
 privateKeyPoint := suite.G2().Point()
 err := privateKeyPoint.UnmarshalBinary(privateKeyByte)
 if err != nil {
  return []byte{}, err
 }
 var destPlainText bytes.Buffer
 var cipherBuffer bytes.Buffer
 _, err = cipherBuffer.Write(cipherBytes)
 if err != nil {
  return []byte{}, err
 }
 err = enc.Decrypt(privateKeyPoint, privateKeyPoint, &destPlainText, &cipherBuffer)
 if err != nil {
  return []byte{}, err
 }
 return []byte(destPlainText.String()), nil

}
```

* Added decryption structures by copying and pasting the below to the bottom of the `contracts.go` file as well.

```go
type decryption struct{}

func (c *decryption) RequiredGas(input []byte) uint64 {
 return params.Bn256PairingBaseGasIstanbul
}

func (c *decryption) Run(input []byte) ([]byte, error) {
 return decrypt(input)
}
```

* Add decryption to the appropriate `PrecompiledContract` vars: `PrecompiledContractsIstanbul`, `PrecompiledContractsBerlin`, `PrecompiledContractsCancun`. Simply paste the following into the respective `PrecompiledContract` vars 

```go
 common.BytesToAddress([]byte{0x94}):&decryption{},
```


### c. Compile the Docker Image with the Precompiles Integrated

```shell
make docker
```

This command will regenerate your `nitro-node` docker image locally. This will be used next to get an updated WASM Module Root (since you have added the pre-compile aspects). 

Now that we have the modified nitro node almost ready to run, we can go ahead and begin setting up the orbit chain settled on the Arbitrum Sepolia network.

## 3. Clone the `orbit-setup-script` Repo and Launch Your Base Contracts on Arbitrum Sepolia Testnet

It is recommended to follow the quickstart provided by the Arbitrum Orbit docs, to set up your own orbit chain. We recommend setting it up with the default settings. The quickstart can be found [here](https://docs.arbitrum.io/launch-orbit-chain/orbit-quickstart). Here, you will deploy your orbit chain to get the configuration files.

> You will need about 1.2 Sepolia ETH for this step.

:::info Make sure to stop after [step 9 in the Arbitrum Orbit Quickstart](https://docs.arbitrum.io/launch-orbit-chain/orbit-quickstart#step-9-clone-the-setup-script-repository-and-add-your-configuration-files)

Come back to this quickstart after finishing step 9. The normal Arbitrum Orbit quickstart will spin up a default nitro node, whereas this quickstart relies on the modified nitro node with new precompile functionalities.
:::

### Checkpoint:

At this point, you will have two repos on your local machines:

1. The `nitro` repo that you had mofied within the first steps of this quickstart.
2. The `orbit-setup-script` repo that has the `Rollup Config` and `L3 Config` details associated to the newly registered base contracts you just created on the Arbitrum Sepolia Testnet.

What needs to be done now includes:

1. Run the docker container for the modified nitro node so it running persistently on your local machine.  
2. Running your orbit-chain locally where it ties into the local node instead of the typical nitro node setup from Arbitrum.

# Start the Local Docker Container for The Modified Nitro Node

Run the following command within the terminal inside of your local nitro repo:

```bash
docker run --rm -it -v $(pwd)/config:/home/user/.arbitrum -p 8449:8449 nitro-node-dev --conf.file /home/user/.arbitrum/nodeConfig.json
```

What this is doing:

- Creating a nitro node local docker container running in the background until it is closed.
- Exposing it via port 8449
- Tagging the docker container under the name `nitro-node-dev`

# Modify the `docker-compose.yaml` File within `orbit-setup-script` repo

The `docker-compose.yaml` file needs to be edited so it is pointing at the local modified nitro node that you just began.

Simply find the `nitro` var within the `docker-compose.yaml` file, and instill the following changes:

```yaml
  nitro:
    image: nitro-node:latest
    ports:
      - "8449:8449"
    volumes:
      - "./config:/home/user/.arbitrum"
    command: --dev
```

# Finish Setting Up Your Chain with Custom Hardhat Setup Script

Using the quickstart resources from the Arbitrum Orbit docs, we can use a pre-made script to carry out necessary setup transactions with the base contracts to complete setting up your local Orbit Chain.

This hardhat script handles the following tasks:

- Fund the batch-poster and validator (staker) accounts on your underlying L2 chain.
- Deposit ETH into your account on the chain using your chain's newly deployed bridge.*
- Deploy your Token Bridge contracts on both L2 and local Orbit chains.
- Configure parameters on the chain. 

> _*You will need a small amount of Sepolia ETH within your respective owner wallet to carry out the script even though we are testing this locally._

To run this script, issue the following command from the root of the orbit-setup-script repository, replacing `OxYourPrivateKey` with the private key of the Owner account you used to deploy your chain's contracts, and replacing http://localhost:8449 with the RPC URL of your chain's node.

Using Arbitrum Sepolia:

```bash
source .env && yarn run setup
```

# Building Out the Dependencies, setting up `.env` and Running Sealed Bid Auction Tests

Now that the config files are where they need to be, build the project out (installing submodules, rust, foundry) by running the following:

```bash
./build.sh
```

This should take about 1-2 minutes but may vary based on your internet connetion speeds.

Next, make sure to update your .env.

> a `.env` file is provided with ready-to-go wallets with a pre-deployed Orbit Chain for your convenience. Please do not go and drain the ETH from these wallets, there's no point anon, it's a test Orbit chain. 💁🏻‍♂️

Finally, we can deploy the the Sealed Bid Auction test contract and run tests against it. This showcases the use of the precompiles within the nitro node on your local docker container. Run the test script by running:

```bash
./sealedBidAuction.sh
```

That's it! At this point you have deployed the Fairblock pre-compile logic onto an EVM, via an Orbit Chain running on your local docker container, and tested it with a sealed bid auction example.

When it comes to the Sealed Bid Auction Example, you will see terminal logs showing that:

- A Sealed Bid Auction Example contract was deployed,
- Encrypted bids were made in the auction, where the encrypted aspect was the bid amount itself using Fairblock technologies.
- Two bids from different private wallets (as per the `.env`) are made, and then the auction ends.
- The sealed bid auction was completed and a winner has been announced with a bid of 200.

# Congratulations
Your local Orbit chain is now running. Let's recap what you've accomplished through this quickstart:

- Modified an EVM such that it works with precompiled functionality specific to Fairyring confidentiality technology.
- Deployed an Arbitrum Orbit chain, `Fairyring Orbit Chain Demo`, that has base contracts registered to the Arbitrum Orbit ecosystem on the Arbitrum Sepolia Testnet.
- Connected the `Fairyring Orbit Chain Demo` to an EVM with encryption and decryption functionality, via a modified nitro node, all in a local docker container. 
- Deployed, and ran a sealed bid auction using the functionality of the Fairblock precompiles on the new EVM Orbit Chain

The key checkpoints highlighted have now provided the key steps to include when modifying your own custom EVM chain to use the Fairyring functionalities. For more specific questions, please reach out either on [Discord](https://discord.gg/jhNBCCAMPK) or our [open issues repo](TODO-GET-LINK).