#!/bin/bash

# Define color codes for formatting
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Get the absolute path of the directory where the script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script directory (where `Cargo.toml` is located)
cd "$script_dir"

# Source the .env file using the absolute path
source "$script_dir/../.env"

echo -e "${BLUE}Starting deployment and interaction script for SealedBidAuctionExample Solidity contract...${NC}"

# Set up configuration variables
echo -e "${YELLOW}Setting up configuration...${NC}"
FEE=10  # Set auction fee, very small so example doesn't brick based on wallet balance

# Get the current block number and set the deadline block to 10 blocks later
CURRENT_BLOCK=$(cast block-number --rpc-url $rpc_url)
DEADLINE_BLOCK=$((CURRENT_BLOCK + 1))

# Deploy the Solidity contract
echo -e "${YELLOW}Deploying SealedBidAuctionExample contract...${NC}"

OUTPUT=$(forge create --broadcast --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 test-simple-auction-solidity/SealedBidAuctionExample.sol:SealedBidAuctionExample --constructor-args $DEADLINE_BLOCK $FEE)2>/dev/null


echo "Forge Output:"
echo "$OUTPUT"


CONTRACT_ADDRESS=$(echo "$OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo -e "${GREEN}Contract deployed at address: $CONTRACT_ADDRESS${NC}"

sleep 5

# Generate shares and extract MasterPublicKey to encrypt the bid data. 
output=$(../ShareGenerator/ShareGenerator generate 1 1 | jq '.')
KEY_SHARE=$(echo "$output" | jq -r '.Shares[0].Value')
PUBLIC_KEY=$(echo "$output" | jq -r '.MasterPublicKey')
echo -e "key share : ${GREEN}$KEY_SHARE${NC}"
echo -e "${YELLOW}NEW PUBLIC KEY GENERATED: $PUBLIC_KEY"

# User 1 sends ETH to User 2 within Orbit Chain (in docker container)
RECIPIENT_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY_2)
AMOUNT="1000000000000000"  # 0.1 ETH in wei

echo "Funding recipient account within Docker chain..."
cast send --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $RECIPIENT_ADDRESS --value $AMOUNT

# User 1 submits a bid using mock bid data from the Rust file
echo -e "${YELLOW}Submitting encrypted bid from user #1...${NC}"

cd ../encrypter
go build
bid_value=200
Encrypted=$(./encrypter "Random_IBE_ID" $PUBLIC_KEY $bid_value)
cd ../test-simple-auction-solidity

cast send --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $CONTRACT_ADDRESS "submitEncryptedBid(bytes)" "0x${Encrypted}" --value $FEE
echo -e "${GREEN}Encrypted bid submitted!${NC}"

#Check Balance
echo "Balance of PRIVATE_KEY_1: $(cast balance $(cast wallet address --private-key $PRIVATE_KEY_1) --rpc-url $rpc_url)"
#Check Balance
echo "Balance of PRIVATE_KEY_2: $(cast balance $(cast wallet address --private-key $PRIVATE_KEY_2) --rpc-url $rpc_url)"

# User 2 submits a bid using mock bid data from the Rust file
echo -e "${YELLOW}Submitting encrypted bid from user #2...${NC}"

cd ../encrypter
bid_value=150
Encrypted=$(./encrypter "Random_IBE_ID" $PUBLIC_KEY $bid_value)
cd ../test-simple-auction-solidity

cast send --rpc-url $rpc_url --private-key $PRIVATE_KEY_2 $CONTRACT_ADDRESS "submitEncryptedBid(bytes)" "0x${Encrypted}" --value $FEE
echo -e "${GREEN}Encrypted bid submitted!${NC}"

# Get DECRYPTION_KEY (keyshare) from ShareGenerator submodule
DECRYPTION_KEY=$(../ShareGenerator/ShareGenerator derive $KEY_SHARE 0 "Random_IBE_ID" | jq -r '.KeyShare')

# Format DECRYPTION_KEY in a way that is needed to test with, named SECRET_KEY
echo -e "${YELLOW}Keyshare obtained from ShareGenerator: $DECRYPTION_KEY"
echo -e "${YELLOW}Encrypted: $Encrypted"

echo -e "${YELLOW}HASH - DOING A CAST CALL!!!${NC}"
cast call 0x0000000000000000000000000000000000000094 "0x${DECRYPTION_KEY}${Encrypted}" --rpc-url $rpc_url

# Decrypt bid results
echo -e "${YELLOW}Revealing bid with secret key...${NC}"
cast send --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $CONTRACT_ADDRESS "revealBids(bytes)" "0x${DECRYPTION_KEY}"

echo -e "${GREEN}Bid revealed!${NC}"

sleep 5

# Check the highest bid and the winner
echo -e "${YELLOW}Checking auction status...${NC}"
HIGHEST_BID=$(cast call --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $CONTRACT_ADDRESS "highestBid()(uint256)")
WINNER=$(cast call --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $CONTRACT_ADDRESS "highestBidder()(address)")
echo -e "${GREEN}highestBid: ${HIGHEST_BID} and highestBidder: ${WINNER}${NC}"

# Issue refunds if there are non-winning bids
echo -e "${YELLOW}Issuing refunds to non-winning bidders...${NC}"
cast send --rpc-url $rpc_url --private-key $PRIVATE_KEY_1 $CONTRACT_ADDRESS "issueRefunds()"
echo -e "${GREEN}Refunds issued.${NC}"