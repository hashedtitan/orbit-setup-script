#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Install dependencies
yarn install

# Move configuration files to the appropriate config directory
cp quickstart/orbitSetupScriptConfig.json config/
cp quickstart/nodeConfig.json config/

# Rename .env.example to .env to use predefined environment variables
if [ -f ".env.example" ]; then
    mv .env.example .env
    echo ".env file has been set up."
else
    echo "Warning: .env.example not found, skipping .env setup."
fi

echo "Orbit setup script repository is set up successfully."

# Run the build setup within the Orbit repo:
echo "Building the dependencies and Orbit chain repo setup..."
./build.sh

### --- NITRO SETUP --- ###

# Move out of orbit repo to clone Nitro
cd ..
if [ ! -d "nitro" ]; then
    echo "Cloning Nitro repository..."
    git clone https://github.com/hashedtitan/nitro.git
else
    echo "Nitro repository already exists, skipping clone."
fi
cd nitro
git checkout feat/fairblock-precompile

# Synchronize and update submodules
echo "Updating submodules..."
git submodule sync
git submodule update --init --recursive --force

# Move necessary files into place
echo "Setting up Nitro..."
cp quickstart/contracts.go go-ethereum/core/vm/
cp quickstart/nodeConfig.json config/

# Build the Nitro node Docker image
echo "Building Nitro Node Docker image..."
make docker

# Ensure the build was successful
if [ $? -eq 0 ]; then
    echo "Docker image build completed successfully."
else
    echo "Error: Docker image build failed." >&2
    exit 1
fi

# Determine the next available Docker container name
BASE_NAME="nitro-node-dev"
NEW_NAME="$BASE_NAME"
INDEX=1

while docker ps -a --format '{{.Names}}' | grep -q "^$NEW_NAME$"; do
    INDEX=$((INDEX + 1))
    NEW_NAME="$BASE_NAME-$INDEX"
done

echo "Starting Nitro node container with name: $NEW_NAME"
docker run -d --name "$NEW_NAME" \
    -v $(pwd)/config:/home/user/.arbitrum \
    -p 8449:8449 \
    nitro-node-dev \
    --conf.file /home/user/.arbitrum/nodeConfig.json

echo "Nitro node is now running in the background with name: $NEW_NAME."
echo "To check logs, use: docker logs -f $NEW_NAME"
echo "To stop the node, use: docker stop $NEW_NAME"

### --- RUN SEALED BID AUCTION TEST --- ###

# Move back to orbit setup repo
cd ../orbit-setup-script

# Run the Sealed Bid Auction test
echo "Running Sealed Bid Auction test..."
/opt/homebrew/bin/bash ./sealedBidAuction.sh

echo "Setup and testing complete!"
