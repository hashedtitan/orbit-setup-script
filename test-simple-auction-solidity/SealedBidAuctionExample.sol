// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Simple Sealed Bid Auction App Example
 * @notice Example Auction App showcasing Solidity and Arbitrum Orbit Integrations with Fairblock. 
 * @dev Functions as a sealed-bid auction where bids are submitted encrypted and revealed using a decryption key once a certain time is passed, triggering the end of the auction. The auctionOwner gets the bid amount; this is assuming that the auction is tied to some offchain deliverable (Art auction etc.).
 * @dev This is purely for educational purposes and is not ready for production. Developers must carry out their own due diligence when it comes to deployment of smart contracts in production, including but not limited to, thorough audits, secure design practices, etc.
 * @dev Actual transference of funds are not enacted within this example, as the main purpose is to showcase the use of encryption and conditional decryption and execution using Fairblock technologies. Decrypted values (bids) can be used with typical smart contract patterns for auction payments.
 */
contract SealedBidAuctionExample {

    /// @notice Represents a bid entry in the auction
    struct BidEntry {
        address bidder;        // Address of the bidder
        bytes encryptedBid;    // Encrypted bid amount
        bool isDecrypted;      // Whether the bid has been decrypted
        uint256 bidValue;      // The actual bid value after decryption
    }

    /// @notice List of all bids in the auction
    BidEntry[] public bids;

    /// @notice Owner of the auction who receives the highest bid amount
    address public auctionOwner;

    /// @notice Reference to precompileAddress where Decryption functionality resides
    address precompileAddress;

    /// @notice Block number after which bids can be revealed
    uint256 public bidCondition;

    /// @notice Fee required to submit a bid
    uint256 public auctionFee;

    /// @notice The highest bid amount after the auction is finalized
    uint256 public highestBid;

    /// @notice The address of the highest bidder
    address public highestBidder;

    /// @notice Indicates if the auction has been finalized
    bool public auctionFinalized;

    /// @dev Event emitted when the auction is initialized
    /// @param deadline The block number after which bids can be revealed
    /// @param fee The fee required to participate in the auction
    event AuctionInitialized(uint256 deadline, uint256 fee);

    /// @dev Event emitted when a new bid is submitted
    /// @param bidder Address of the bidder
    /// @param bidIndex Index of the bid in the bids array
    event BidSubmitted(address bidder, uint256 bidIndex);

    /// @dev Event emitted when the auction is finalized
    /// @param winner Address of the winning bidder
    /// @param winningBid The highest bid amount
    event AuctionFinalized(address winner, uint256 winningBid);

    /// @dev Event emitted when a refund is issued to a non-winning bidder
    /// @param bidder Address of the bidder receiving the refund
    /// @param amount Amount refunded
    event RefundIssued(address bidder, uint256 amount);

    /**
     * @notice Initializes the auction with a decryption contract, a deadline, and a fee.
     * @param _deadline The block number after which bids can be revealed
     * @param _fee The fee required to submit a bid
     */
    constructor(uint256 _deadline, uint256 _fee) {
        auctionOwner = msg.sender;
        precompileAddress = address(0x0000000000000000000000000000000000000094);
        bidCondition = _deadline;
        auctionFee = _fee;
        auctionFinalized = false;
        emit AuctionInitialized(_deadline, _fee);

    }

    /**
     * @notice Submits an encrypted bid along with the required fee.
     * @param encryptedBid The encrypted bid value in `bytes` format
     */
    function submitEncryptedBid(bytes calldata encryptedBid) 
        external 
        payable 
    {
        require(block.timestamp > bidCondition, "Auction deadline passed");
        // require(msg.value >= auctionFee, "Insufficient fee");

        bids.push(BidEntry({
            bidder: msg.sender,
            encryptedBid: encryptedBid,
            isDecrypted: false, 
            bidValue: 0
        }));

        emit BidSubmitted(msg.sender, bids.length - 1);
    }

    /**
     * @notice Reveals all bids using the provided decryption key and determines the winner.
     * @param decryptionKey The decryption key to unlock the encrypted bids
     */
    function revealBids(bytes calldata decryptionKey) external {
    require(block.timestamp >= bidCondition, "Auction still ongoing");
    require(!auctionFinalized, "Auction already finalized");

    uint256 highestBidLocal = 0;
    address highestBidderLocal = address(0);

    for (uint256 i = 0; i < bids.length; i++) {
        (bool success, bytes memory decryptedData) = precompileAddress.call(
            abi.encodePacked(decryptionKey, bids[i].encryptedBid)
        );

        // If decryption fails or data is empty, mark the bid as invalid
        if (!success || decryptedData.length == 0) {
            bids[i].isDecrypted = true;
            bids[i].bidValue = 0; // Mark as invalid
            continue;
        }

        // Decode the bid value, handle variable-length data
        uint256 bidValue;
        bidValue = asciiBytesToUint(decryptedData);

        // Optional: Validate bidValue is within an acceptable range
        require(bidValue > 0 && bidValue <= type(uint256).max / 2, "Invalid bid value");

        // Mark the bid as decrypted
        bids[i].isDecrypted = true;
        bids[i].bidValue = bidValue;

        // Update the highest bid and bidder
        if (bidValue > highestBidLocal) {
            highestBidLocal = bidValue;
            highestBidderLocal = bids[i].bidder;
        }
    }

    // Finalize the auction
    highestBid = highestBidLocal;
    highestBidder = highestBidderLocal;
    auctionFinalized = true;

    emit AuctionFinalized(highestBidder, highestBid);
}

    /**
     * @notice Issues refunds to all non-winning bidders after the auction is finalized.
     */
    function issueRefunds() external {
        require(auctionFinalized, "Auction not finalized");

        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].bidder != highestBidder) {
                uint256 refundAmount = bids[i].bidValue - auctionFee;
                // payable(bids[i].bidder).transfer(refundAmount);
                emit RefundIssued(bids[i].bidder, refundAmount);
            }
        }
    }

    function asciiBytesToUint(bytes memory data) public pure returns (uint256) {
    uint256 number;
    for (uint256 i = 0; i < data.length; i++) {
        number = number * 10 + (uint8(data[i]) - 48);
    }
    return number;
}
}
