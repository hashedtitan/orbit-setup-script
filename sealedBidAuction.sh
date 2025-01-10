set -e  # Stop on any error

chmod +x sealedBidAuction.sh

# Navigate to the test-simple-auction-solidity directory and run the test
echo "Navigating to the 'test-simple-auction-solidity' directory and running the test..."
cd test-simple-auction-solidity
./test.sh

echo "Integration tests completed successfully!"