// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Define an interface for the IERC4907 contract
interface IERC4907 {
    // Logged when the user of an NFT is changed or expires is changed
    /// @notice Emitted when the `user` of an NFT or the `expires` of the `user` is changed
    /// The zero address for user indicates that there is no user address
    event UpdateUser(
        uint indexed tokenId,
        address indexed user,
        uint64 expires
    );

    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(uint tokenId, address user, uint64 expires) external;

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(uint tokenId) external view returns (address);

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(uint tokenId) external view returns (uint);
}

// Rentable NFT Marketplace contract
contract Master is Ownable {
    using SafeMath for uint;

    using Counters for Counters.Counter;
    Counters.Counter private totalRentalListing;
    Counters.Counter private auctionIdCounter;

    address feeTo;
    uint feeCollected;

    // Structure to store NFT listing details.
    //paymentToken should be address(0) in case of native currency else it shoud be the address of the ERC20 tokens like WETH,USDT,USDC
    //costPerHour should be in wei or multiplied by token decimal.
    struct Rental {
        address owner;
        address nftContract;
        uint tokenId;
        address paymentToken;
        uint costPerHour;
        uint minAllowedHours;
        uint maxAllowedHours;
        address renter;
        uint rentedHours;
        uint startTime;
        RentalStatus rentalStatus;
    }

    enum RentalStatus {
        Listed,
        Rented,
        NotListed
    }

    RentalStatus private rentalStatus;

    // Mapping to store NFT rentalListings
    mapping(address => mapping(uint => Rental)) public rentalListings;

    // Struct to represent an auction
    //reservePrice should be in wei or multiplied by token decimal.
    struct Auction {
        address seller;
        address nftContract;
        uint tokenId;
        address paymentToken;
        uint reservePrice;
        uint startTime;
        uint endTime;
        uint highestBid;
        address highestBidder;
        bool ended;
        AuctionStatus auctionStatus;
    }

    enum AuctionStatus {
        Listed,
        BidPlaced,
        Auctioned,
        NotListed
    }
    AuctionStatus public auctionStatus;

    // Mapping from token address and token ID to its corresponding auction

    mapping(address => mapping(uint => Auction)) public auctions;

    // Duration of the auction (in seconds) 24 hours
    uint public auctionDuration = 15 minutes;

    // Duration to extend the auction when a bid is received in the last minutes , 15 min
    uint public extensionDuration = 5 minutes;
    // in bps
    uint public platformFee = 200;

    // Rental Events
    event NFTListedForRent(
        address indexed owner,
        address indexed nftContract,
        uint tokenId,
        address paymentToken,
        uint costPerHour,
        uint minAllowedHours,
        uint maxAllowedHours,
        address indexed renter,
        uint rentedHours,
        uint startTime,
        RentalStatus rentalStatus
    );

    event NFTRented(
        address indexed nftContract,
        uint tokenId,
        address indexed renter,
        uint rentedDays,
        uint startTime
    );

    event NFTClaimed(address indexed nftContract, uint tokenId);

    event AuctionExtended(
        address indexed nftContract,
        uint tokenId,
        uint endtime
    );

    //Auction Events

    event NFTListedForAuction(
        address indexed seller,
        address indexed nftContract,
        uint tokenId,
        address paymentToken,
        uint reservePrice,
        uint startTime,
        uint endTime,
        uint highestBid,
        address highestBidder,
        bool ended,
        AuctionStatus auctionStatus
    );

    event BidRecieved(
        address indexed owner,
        address indexed nftContract,
        uint tokenId,
        uint amount
    );

    event AuctionEnded(
        address indexed nftContract,
        uint tokenId,
        address seller,
        address highestBidder,
        uint highestBid
    );

    event NFTListedForRentUpdated(
        address indexed owner,
        address indexed nftContract,
        uint tokenId
    );

    // Modifier to ensure that the caller is the NFT owner or has approval

    modifier onlyOwnerOrApproved(address _nftContract, uint _tokenId) {
        address tokenOwner = IERC721(_nftContract).ownerOf(_tokenId);
        address tokenApprover = IERC721(_nftContract).getApproved(_tokenId);

        require(
            msg.sender == tokenOwner || msg.sender == tokenApprover,
            "Not the NFT owner or approved"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        feeTo = owner();
    }

    // Function to list an NFT for rent
    function listNFTForRent(
        address _nftContract,
        uint _tokenId,
        address _paymentToken,
        uint _costPerHour,
        uint _minAllowedHours,
        uint _maxAllowedHours
    ) public onlyOwnerOrApproved(_nftContract, _tokenId) {
        require(
            (rentalListings[_nftContract][_tokenId].owner == address(0)),
            "Listing already exists"
        );

        // The contract should have approvals to use the NFT
        require(
            address(this) == IERC721(_nftContract).getApproved(_tokenId),
            "Not Authorized"
        );
        totalRentalListing.increment();

        rentalListings[_nftContract][_tokenId] = Rental({
            owner: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            paymentToken: _paymentToken,
            costPerHour: _costPerHour,
            minAllowedHours: _minAllowedHours,
            maxAllowedHours: _maxAllowedHours,
            renter: address(0),
            rentedHours: 0,
            startTime: 0,
            rentalStatus: RentalStatus.Listed
        });

        emit NFTListedForRent(
            msg.sender,
            _nftContract,
            _tokenId,
            _paymentToken,
            _costPerHour,
            _minAllowedHours,
            _maxAllowedHours,
            address(0),
            0,
            0,
            RentalStatus.Listed
        );
    }

    // update rental Listing

    function updateRentalListing(
        address _nftContract,
        uint _tokenId,
        address _paymentToken,
        uint _costPerHour,
        uint _minAllowedHours,
        uint _maxAllowedHours
    ) public onlyOwnerOrApproved(_nftContract, _tokenId) {
        require(
            (rentalListings[_nftContract][_tokenId].owner != address(0)),
            "Listing doesn't exists"
        );

        // The contract should have approvals to use the NFT
        require(
            address(this) == IERC721(_nftContract).getApproved(_tokenId),
            "Not Authorized"
        );

        Rental storage rental = rentalListings[_nftContract][_tokenId];

        rental.paymentToken = _paymentToken;
        rental.costPerHour = _costPerHour;
        rental.minAllowedHours = _minAllowedHours;
        rental.minAllowedHours = _minAllowedHours;
        rental.maxAllowedHours = _maxAllowedHours;

        emit NFTListedForRentUpdated(msg.sender, _nftContract, _tokenId);
    }

    // Function to rent an NFT
    function rentNFT(
        address _nftContract,
        uint _tokenId,
        uint _rentedHours,
        address _paymentToken
    ) external payable {
        Rental storage listing = rentalListings[_nftContract][_tokenId];
        // Check if the rental listing exists for the given NFT
        require(listing.owner != address(0), "Rental listing does not exist");

        // Ensure that the NFT is not already rented
        require(listing.renter == address(0), "NFT is already rented");

        // Ensure that the requested rental period is within the allowed range
        require(
            _rentedHours >= listing.minAllowedHours &&
                _rentedHours <= listing.maxAllowedHours,
            "Incorrect rental period"
        );
        address tokenAddress = listing.paymentToken;
        // Ensure the provided payment token matches the expected payment token
        require(_paymentToken == tokenAddress, "Incorrect payment token");

        if (tokenAddress == address(0)) {
            uint totalWei = _rentedHours * listing.costPerHour;
            require(msg.value >= totalWei, "Insufficient funds");
        } else {
            uint totalTokens = _rentedHours * listing.costPerHour;
            // Ensure the contract is approved to spend the required amount of tokens
            require(
                IERC20(tokenAddress).allowance(msg.sender, address(this)) >=
                    totalTokens,
                "Allowance not set"
            );
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    totalTokens
                ),
                "Rent payment failed"
            );
        }

        listing.renter = msg.sender;
        listing.rentedHours = _rentedHours;
        listing.startTime = block.timestamp;
        listing.rentalStatus = RentalStatus.Rented;

        // Call setUser function of IERC4907 contract to set the renter
        IERC4907(listing.nftContract).setUser(
            listing.tokenId,
            msg.sender,
            uint64(block.timestamp + (_rentedHours * 3600 seconds))
        );

        // Transfer NFT to an escrow contract
        IERC721(listing.nftContract).safeTransferFrom(
            listing.owner,
            address(this),
            listing.tokenId
        );
        // Remove Auction Listing
        _updateAuctionStatus(_nftContract, _tokenId, AuctionStatus.NotListed);

        emit NFTRented(
            _nftContract,
            _tokenId,
            msg.sender,
            _rentedHours,
            block.timestamp
        );
    }

    // Function for the owner to claim the NFT after rental period
    function claimRentalNFT(
        address _nftContract,
        uint _tokenId
    ) external payable {
        Rental storage listing = rentalListings[_nftContract][_tokenId];
        require(msg.sender == listing.owner, "No Authorized");
        require(
            listing.rentalStatus == RentalStatus.Rented &&
                block.timestamp > getRentalExpiry(_nftContract, _tokenId),
            "Rental Not expired"
        );
        address paymentToken = listing.paymentToken;
        address nftOwner = listing.owner;

        uint totalAmount = listing.rentedHours * listing.costPerHour;
        uint fee = totalAmount.mul(platformFee).div(10 ** 4);
        uint claimableRent = totalAmount.sub(fee);

        // Reset rental information
        _removeRentalListing(_nftContract, _tokenId);
        // Call the setUser function from the IERC4907 interface to clear the user and expiration
        IERC4907(_nftContract).setUser(_tokenId, address(0), 0);
        feeCollected = feeCollected.add(fee);

        //Pay the rental amount to the owner

        _sendFunds(paymentToken, nftOwner, claimableRent);
        _sendFunds(paymentToken, feeTo, fee);

        // Transfer the NFT back to the owner
        IERC721(listing.nftContract).transferFrom(
            address(this),
            nftOwner,
            _tokenId
        );
        //Relist for auction
        if (auctions[_nftContract][_tokenId].seller != address(0)) {
            _updateAuctionStatus(_nftContract, _tokenId, AuctionStatus.Listed);
        }

        emit NFTClaimed(_nftContract, _tokenId);
    }

    function isRentalNFTClaimable(
        address _nftContract,
        uint _tokenId
    ) external view returns (bool isClaimable) {
        Rental storage listing = rentalListings[_nftContract][_tokenId];
        //require(msg.sender == listing.owner, "No Authorized");
        require(
            listing.rentalStatus == RentalStatus.Rented,
            "NFT not rented yet"
        );
        if (block.timestamp > getRentalExpiry(_nftContract, _tokenId)) {
            return true;
        } else {
            return false;
        }
    }

    function removeRentalListing(
        address _nftContract,
        uint _tokenId
    ) public onlyOwnerOrApproved(_nftContract, _tokenId) {
        Rental storage listing = rentalListings[_nftContract][_tokenId];
        // Check if the rental listing exists for the given NFT
        require(listing.owner != address(0), "Rental listing does not exist");

        // Ensure that the NFT is not already rented
        require(listing.renter == address(0), "NFT is already rented");
        _removeRentalListing(_nftContract, _tokenId);
    }

    function _removeRentalListing(
        address _nftContract,
        uint _tokenId
    ) internal {
        delete rentalListings[_nftContract][_tokenId];
        totalRentalListing.decrement();
    }

    function _updateRentalStatus(
        address _nftContract,
        uint _tokenId,
        RentalStatus _status
    ) internal {
        rentalListings[_nftContract][_tokenId].rentalStatus = _status;
    }

    // Function to retrieve the details of a listed NFT
    function getRentalListingDetails(
        address _nftContract,
        uint _tokenId
    ) external view returns (Rental memory) {
        return rentalListings[_nftContract][_tokenId];
    }

    // get the remaing expiry time in sec
    function getRentalExpiry(
        address _nftContract,
        uint _tokenId
    ) public view returns (uint) {
        Rental memory listing = rentalListings[_nftContract][_tokenId];
        return
            block.timestamp.sub(
                IERC4907(listing.nftContract).userExpires(listing.tokenId)
            );
    }

    function getRentalAmount(
        address _nftContract,
        uint _tokenId
    ) public view returns (address tokenAddress, uint amount) {
        Rental memory listing = rentalListings[_nftContract][_tokenId];
        return (
            listing.paymentToken,
            listing.rentedHours * listing.costPerHour
        );
    }

    function getHourlyRent(
        address _nftContract,
        uint _tokenId
    ) public view returns (address tokenAddress, uint amount) {
        return (
            rentalListings[_nftContract][_tokenId].paymentToken,
            rentalListings[_nftContract][_tokenId].rentedHours
        );
    }

    function getRentStartTime(
        address _nftContract,
        uint _tokenId
    ) public view returns (uint startTime) {
        return (rentalListings[_nftContract][_tokenId].startTime);
    }

    function getRenter(
        address _nftContract,
        uint _tokenId
    ) public view returns (address rentert) {
        return (rentalListings[_nftContract][_tokenId].renter);
    }

    function setRentalPlatformFee(uint _feeBPS) public onlyOwner {
        platformFee = _feeBPS;
    }

    // Auction

    // Create a new auction for an ERC721 token
    function listForAuction(
        address _nftContract,
        uint _tokenId,
        address _paymentToken,
        uint _reservePrice
    ) public onlyOwnerOrApproved(_nftContract, _tokenId) {
        require(_reservePrice > 0, "Reserve price must be greater than zero");
        // Allow only if listing is not already present
        require(
            auctions[_nftContract][_tokenId].seller == address(0),
            "Listing already exists"
        );
        // Approve Master contract to move your NFTs
        require(
            address(this) == IERC721(_nftContract).getApproved(_tokenId),
            "Not Authorized"
        );

        auctionIdCounter.increment();
        auctions[_nftContract][_tokenId] = Auction(
            msg.sender,
            _nftContract,
            _tokenId,
            _paymentToken,
            _reservePrice,
            block.timestamp,
            0,
            0,
            address(0),
            false,
            AuctionStatus.Listed
        );

        emit NFTListedForAuction(
            msg.sender,
            _nftContract,
            _tokenId,
            _paymentToken,
            _reservePrice,
            block.timestamp,
            block.timestamp.add(auctionDuration),
            0,
            address(0),
            false,
            AuctionStatus.Listed
        );
    }

    // Place a bid on an ongoing auction
    // TODO: Add events
    function placeBid(
        address _nftContract,
        uint _tokenId,
        address _paymentToken,
        uint _amount
    ) external payable {
        Auction storage auction = auctions[_nftContract][_tokenId];
        require(
            auction.auctionStatus == AuctionStatus.Listed,
            "Auction does not exist"
        );
        // require(!auction.ended, "Auction has already ended"); // taken care by below check
        // require(block.timestamp < auction.endTime, "Auction has already ended");

        // Ensure the provided payment token matches the expected payment token
        address tokenAddress = auction.paymentToken;
        require(_paymentToken == tokenAddress, "Incorrect payment token");

        if (tokenAddress == address(0)) {
            require(
                msg.value > auction.highestBid &&
                    msg.value >= auction.reservePrice &&
                    msg.value == _amount,
                "Bid must be higher than the current highest bid plus the minimum increment"
            );
        } else {
            require(
                IERC20(tokenAddress).allowance(msg.sender, address(this)) >=
                    _amount,
                "Allowance not set"
            );
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    _amount
                ),
                "Bid not placed"
            );
        }
        // If this is the first bidder, transfer the NFT to the contract

        if (auction.highestBidder == address(0)) {
            auction.endTime = block.timestamp.add(auctionDuration);
            IERC721(auction.nftContract).transferFrom(
                auction.seller,
                address(this),
                auction.tokenId
            );
        }

        if (auction.highestBidder != address(0)) {
            // Refund the previous highest bidder
            _sendFunds(tokenAddress, auction.highestBidder, auction.highestBid);
        }

        auction.highestBid = _amount;
        auction.highestBidder = msg.sender;
        auction.auctionStatus = AuctionStatus.BidPlaced;

        // Extend the auction if a bid is received in the last 15 minutes
        if (auction.endTime.sub(block.timestamp) <= extensionDuration) {
            auction.endTime = block.timestamp.add(extensionDuration);
        }

        //Cancel rental Listing
        _updateRentalStatus(_nftContract, _tokenId, RentalStatus.NotListed);

        emit BidRecieved(msg.sender, _nftContract, _tokenId, msg.value);
    }

    // End an auction and transfer the NFT to the highest bidder
    function endAuction(
        address _nftContract,
        uint _tokenId,
        address[] calldata _royaltyAddress,
        uint[] memory _royaltyBps
    ) external {
        Auction storage auction = auctions[_nftContract][_tokenId];
        require(auction.endTime > 0, "Auction does not exist");
        require(
            block.timestamp >= auction.endTime,
            "Auction has not ended yet"
        );
        require(!auction.ended, "Auction has already ended");
        address tokenAddress = auction.paymentToken;
        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            // Transfer the NFT to the highest bidder
            IERC721(auction.nftContract).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
        }

        // Seller Payout

        if (auction.highestBid > 0) {
            uint fee = auction.highestBid.mul(platformFee).div(10 ** 4);
            uint sellerAmountBeforeRoyalty = auction.highestBid.sub(fee);

            // royality Payout
            uint royaltyPayout;
            for (uint i = 0; i < _royaltyAddress.length; i++) {
                uint royaltyAmount = auction.highestBid.mul(_royaltyBps[i]).div(
                    10 ** 4
                );
                _sendFunds(tokenAddress, _royaltyAddress[i], royaltyAmount);
                royaltyPayout += royaltyAmount;
            }

            uint sellerAmountAfterRoyalty = sellerAmountBeforeRoyalty -
                royaltyPayout;
            _sendFunds(tokenAddress, auction.seller, sellerAmountAfterRoyalty);
            _sendFunds(tokenAddress, feeTo, fee);
        }
        //ReList rental
        _updateRentalStatus(_nftContract, _tokenId, RentalStatus.Listed);
        _removeAuctionListing(_nftContract, _tokenId);
        //  _updateAuctionStatus(_nftContract, _tokenId,AuctionStatus.NotListed);
        // TODO auction.auctionStatus = resetAuctionStatus();
        //TODO Remove ended variable
        auctionIdCounter.decrement();

        emit AuctionEnded(
            _nftContract,
            _tokenId,
            auction.seller,
            auction.highestBidder,
            auction.highestBid
        );
    }

    function _sendFunds(
        address tokenAddress,
        address _recipient,
        uint _sellerAmount
    ) internal {
        if (tokenAddress == address(0)) {
            payable(_recipient).transfer(_sellerAmount);
        } else {
            require(
                IERC20(tokenAddress).transfer(_recipient, _sellerAmount),
                "Payment failed"
            );
        }
    }

    // Function to retrieve the details of a listed NFT

    function getAuctionListingDetails(
        address _nftContract,
        uint tokenId
    ) external view returns (Auction memory) {
        return auctions[_nftContract][tokenId];
    }

    function getHighestBid(
        address _nftContract,
        uint tokenId
    ) public view returns (uint) {
        return auctions[_nftContract][tokenId].highestBid;
    }

    function getAuctionEndTime(
        address _nftContract,
        uint tokenId
    ) public view returns (uint) {
        return auctions[_nftContract][tokenId].endTime;
    }

    function getHighestBidder(
        address _nftContract,
        uint tokenId
    ) public view returns (address) {
        return auctions[_nftContract][tokenId].highestBidder;
    }

    function getAuctionReservePrice(
        address _nftContract,
        uint tokenId
    ) public view returns (uint) {
        return auctions[_nftContract][tokenId].reservePrice;
    }

    function getAuctionStatus(
        address _nftContract,
        uint tokenId
    ) public view returns (bool) {
        return auctions[_nftContract][tokenId].ended;
    }

    // Update the auction duration (only owner)
    function setAuctionDuration(uint _duration) external onlyOwner {
        auctionDuration = _duration;
    }

    // Update the extension duration (only owner)
    function setExtensionDuration(uint _duration) external onlyOwner {
        extensionDuration = _duration;
    }

    function removeAuctionListing(
        address _nftContract,
        uint _tokenId
    ) public onlyOwnerOrApproved(_nftContract, _tokenId) {
        Auction storage auction = auctions[_nftContract][_tokenId];
        require(auction.endTime > 0, "Auction does not exist");
        _removeAuctionListing(_nftContract, _tokenId);
    }

    function _removeAuctionListing(
        address _nftContract,
        uint _tokenId
    ) internal {
        delete auctions[_nftContract][_tokenId];
        auctionIdCounter.decrement();
    }

    function _updateAuctionStatus(
        address _nftContract,
        uint _tokenId,
        AuctionStatus _status
    ) internal {
        auctions[_nftContract][_tokenId].auctionStatus = _status;
    }

    // integratd functions

    function bulkListNFTForRentAndAuction(
        address _nftContracts,
        uint[] memory _tokenIds,
        address _paymentTokens,
        uint _costsPerHour,
        uint _minAllowedHours,
        uint _maxAllowedHours,
        uint _reservePrices
    ) external {
        for (uint i = 0; i < _tokenIds.length; i++) {
            listNFTForRent(
                _nftContracts,
                _tokenIds[i],
                _paymentTokens,
                _costsPerHour,
                _minAllowedHours,
                _maxAllowedHours
            );
            listForAuction(
                _nftContracts,
                _tokenIds[i],
                _paymentTokens,
                _reservePrices
            );
        }
    }

    // Set the 'feeTo' address
    function setFeeTo(address _newFeeTo) public onlyOwner {
        feeTo = _newFeeTo;
    }

    // Get the 'feeTo' address
    function getFeeTo() public view returns (address) {
        return feeTo;
    }

    // delete resets the enum to its first value, 0
    function resetRentalStatus() public {
        delete rentalStatus;
    }

    function _resetAuctionStatus() public {
        delete auctionStatus;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
