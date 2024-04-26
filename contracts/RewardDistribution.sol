/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

// Importing OpenZeppelin contracts for  Merkle proof verification, and ownership management.
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IGovernor.sol";
import "./ISentimentScore.sol";

// Contract for distributing rewards, extends ERC20 token functionality and ownership features.
contract RewardDistribution is AccessControl, ReentrancyGuard {
    // Structure to hold assignment details including governance list, Merkle root, amount, and active status.
    struct Assignment {
        mapping(uint => bool) claimed; // Governor TokenId
        bytes32 merkleRoot; // merkleRoot is for a tress whose leaf is [Gov TokenID and Claimable Amount]
        uint256 amount;
        bool isActive;
        uint createdAt;
        uint noOfGovernors;
    }

    mapping(address => Assignment) private Assignments; // Mapping from product owner to their assignment.
    uint256 private assessmentCost = 2000 * 10 ** 18; // The cost required for assessment.
    address public immutable paymentToken; // Address of the Payment Token .
    address payable private treasury; // Address of the treasury to collect fees or unused funds.
    address governorNFT;
    address scoreNFT;

    uint private fee = 200; // In basis points i.e., 2%
    uint256 private constant BASIS_POINTS_TOTAL = 10000;
    uint private totalfee;

    mapping(uint => uint256) public lastClaimedRewardPerToken;
    uint256 public totalRewardPerToken;
    uint256 public totalDistributedRewards;

    // Events for logging activities on the blockchain.
    event AssignmentCreated(address _user, uint256 claimableAmount);
    event MerkleRootAdded(address productId, bytes32 merkleRoot);
    event RewardsClaimed(
        address productId,
        address userAddress,
        uint256 rewardAmount
    );
    event DividendDistributed(uint256 amount);
    event DividendClaimed(uint tokenId, uint256 amount);

    // Constructor to set initial values for USDT token address and treasury.
    constructor(
        address _paymentToken,
        address _treasury,
        address _governorNFT,
        address _scoreNFT
    ) {
        require(
            _paymentToken != address(0),
            "Payment Token address cannot be zero"
        );
        require(_treasury != address(0), "Treasury address cannot be zero");
        require(
            _governorNFT != address(0),
            "GovernanceNFT address cannot be zero"
        );
        require(
            _scoreNFT != address(0),
            "SentimentScore address cannot be zero"
        );

        paymentToken = _paymentToken;
        treasury = payable(_treasury);
        governorNFT = _governorNFT;
        scoreNFT = _scoreNFT;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Function to create an assignment by product owners.
    function createAssignment() external {
        require(
            Assignments[msg.sender].createdAt == 0,
            "Assignment already created"
        );

        uint256 feeAmount = (assessmentCost * uint256(fee)) /
            BASIS_POINTS_TOTAL;
        require(
            IERC20(paymentToken).balanceOf(msg.sender) >= assessmentCost,
            "Insufficient funds to cover assessment"
        );

        require(
            IERC20(paymentToken).transferFrom(
                msg.sender,
                address(this),
                assessmentCost
            ),
            "Transfer failed"
        );
        require(
            IERC20(paymentToken).transfer(treasury, feeAmount),
            "Token transfer failed"
        );

        // Explicitly initializing the Assignment struct
        Assignment storage assignment = Assignments[msg.sender];
        assignment.amount = assessmentCost - feeAmount;
        assignment.isActive = false; // Explicitly setting to false initially
        assignment.createdAt = block.timestamp; // Setting the creation time
        assignment.noOfGovernors = 0; // Initialize to 0, update when known

        totalfee += feeAmount;

        emit AssignmentCreated(msg.sender, assessmentCost);
    }

    function distributeDividends(
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_amount > 0, "Amount must be positive");
        require(
            IERC20(paymentToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Transfer failed"
        );

        uint256 totalTokens = IGovernor(governorNFT).totalSupply();
        if (totalTokens > 0) {
            uint256 rewardPerTokenIncrease = _amount / totalTokens;
            totalRewardPerToken += rewardPerTokenIncrease;
            totalDistributedRewards += _amount;
        }

        emit DividendDistributed(_amount);
    }

    function claimDividend(uint _tokenId) external nonReentrant {
        require(
            IGovernor(governorNFT).ownerOf(_tokenId) == msg.sender,
            "Caller is not the token owner"
        );
        uint256 lastClaimed = lastClaimedRewardPerToken[_tokenId];
        uint256 claimableReward = totalRewardPerToken - lastClaimed;

        require(claimableReward > 0, "No reward available");

        lastClaimedRewardPerToken[_tokenId] = totalRewardPerToken;
        require(
            IERC20(paymentToken).transfer(msg.sender, claimableReward),
            "Token transfer failed"
        );

        emit DividendClaimed(_tokenId, claimableReward);
    }

    function getDevidend(uint _tokenId) external view returns (uint rewards) {
        uint256 lastClaimed = lastClaimedRewardPerToken[_tokenId];
        return totalRewardPerToken - lastClaimed;
    }

    function getAssignment(
        address _productId
    ) external view returns (bytes32, uint, bool, uint) {
        return (
            Assignments[_productId].merkleRoot,
            Assignments[_productId].amount,
            Assignments[_productId].isActive,
            Assignments[_productId].createdAt
        );
    }

    function getClaimStatusOfReward(address _projectOwner,uint _govId) public view returns(bool){
        return Assignments[_projectOwner].claimed[_govId];
    }

    // Admin function to set the Merkle root for reward distribution.
    //This will mint scoreNFT
    function mintSentimentScoreNFT(
        address _productId,
        bytes32 _merkleRoot,
        uint _noOfGovernors,
        string memory _scoreNftUri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ISentimentScore nft = ISentimentScore(scoreNFT);
        require(
            Assignments[_productId].createdAt != 0,
            "Assignment doesn't exists"
        );
        Assignments[_productId].merkleRoot = _merkleRoot;
        Assignments[_productId].isActive = true;
        Assignments[_productId].noOfGovernors = _noOfGovernors;
        nft.safeMint(_productId, _scoreNftUri);
        emit MerkleRootAdded(_productId, _merkleRoot);
    }

    // Admin function to update the assessment cost.
    function setAssessmentCost(
        uint256 _newCost
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assessmentCost = _newCost;
    }

    function setFee(uint256 _newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fee = _newFee;
    }

    function getFee() external view returns (uint platformfee) {
        return fee;
    }

    // Admin function to update the treasury address.
    function setNewTreasury(
        address _newTreasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = payable(_newTreasury);
    }

    // Admin function to enable or disable reward claims for a product owner.
    function setRewardClaim(
        address _productId,
        bool _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Assignments[_productId].isActive = _status;
    }

    // Function for users to claim their rewards.
    function claimReward(
        address _productId,
        bytes32[] calldata proof,
        uint _tokenId
    ) external nonReentrant {
        IGovernor govNFT = IGovernor(governorNFT);
        require(govNFT.balanceOf(msg.sender) == 1, "Not Authorized");
        require(govNFT.ownerOf(_tokenId) == msg.sender, "Not Authorized");

        // get the Gov NFT token id owned by caller
        require(
            Assignments[_productId].isActive,
            "Reward is not active for this Product"
        );
        require(
            IERC20(paymentToken).balanceOf(address(this)) >=
                Assignments[_productId].amount,
            "Insufficient Reward"
        );
        require(
            !(Assignments[_productId].claimed[_tokenId]),
            "Already claimed"
        );

        bytes32 merkleRoot = Assignments[_productId].merkleRoot;
        _verifyProof(merkleRoot, proof, _tokenId);

        uint rewardPerGovernor = Assignments[_productId].amount /
            Assignments[_productId].noOfGovernors;

        Assignments[_productId].claimed[_tokenId] = true;
        govNFT._addProduct(_tokenId, _productId);

        require(
            IERC20(paymentToken).transfer(msg.sender, rewardPerGovernor),
            "Token transfer failed"
        );

        emit RewardsClaimed(_productId, msg.sender, rewardPerGovernor);
    }

    function getrewards(
        address _productId
    ) external view returns (uint rewards) {
        return
            Assignments[_productId].amount /
            Assignments[_productId].noOfGovernors;
    }

    // Private function to verify Merkle proof for claim verification.
    function _verifyProof(
        bytes32 _merkleRoot,
        bytes32[] memory proof,
        uint tokenId
    ) private pure {
        bytes32 leaf = keccak256(abi.encode(tokenId));
        require(MerkleProof.verify(proof, _merkleRoot, leaf), "Invalid proof");
    }

    // Admin function to transfer tokens from the contract to the treasury.
    function withdrawDonatedTokens(
        address _tokenAddress,
        uint256 _value
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            IERC20(_tokenAddress).transfer(treasury, _value),
            "Token transfer failed"
        );
    }

    // Admin function to transfer ETH from the contract to the treasury.
    function withdrawDonatedETH()
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(address(this).balance > 0, "Insufficient Balance");
        payable(treasury).transfer(address(this).balance);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}
}
