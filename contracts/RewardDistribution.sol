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
import "./IGovernor.sol";
import "./ISentimentScore.sol";

// Interface for non-standard ERC20 tokens to handle tokens that do not return a boolean on transfer and transferFrom.
interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function decimals() external view returns (uint256);
    function transfer(address dst, uint256 amount) external;
    function transferFrom(address src, address dst, uint256 amount) external;
    function approve(
        address spender,
        uint256 amount
    ) external returns (bool success);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256 remaining);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}

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

    mapping(address => Assignment) Assignments; // Mapping from product owner to their assignment.
    uint256 assessmentCost = 2000; // The cost required for assessment.
    address public immutable USDT; // Address of the USDT token.
    address payable treasury; // Address of the treasury to collect fees or unused funds.
    address governanceNFT;
    address sentimentScore;

    uint private fee = 200; //in bps i.e 2%
    uint totalfee;

    mapping(uint => uint256) public lastClaimedRewardPerToken;
    uint256 public totalRewardPerToken;
    uint256 public totalDistributedRewards;

    // uint public cumulativeRewards;
    // uint public rewardPerTokenId;

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
        address _usdt,
        address _treasury,
        address _governanceNFT,
        address _sentimentScore
    ) {
        require(_usdt != address(0), "USDT address cannot be zero");
        require(_treasury != address(0), "Treasury address cannot be zero");
        require(
            _governanceNFT != address(0),
            "GovernanceNFT address cannot be zero"
        );
        require(
            _sentimentScore != address(0),
            "SentimentScore address cannot be zero"
        );

        USDT = _usdt;
        treasury = payable(_treasury);
        governanceNFT = _governanceNFT;
        sentimentScore = _sentimentScore;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Function to create an assignment by product owners.
    function createAssignment() external {
        require(
            Assignments[msg.sender].createdAt == 0,
            "Assignment already created"
        );
        // require(
        //     _amount >=
        //         assessmentCost * 10 ** INonStandardERC20(USDT).decimals(),
        //     "Invalid Amount"
        // );

        uint256 feeAmount = (assessmentCost * uint256(fee)) / 10000;
        doTransferOut(USDT, treasury, feeAmount);
        doTransferIn(USDT, msg.sender, assessmentCost - feeAmount);

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
        doTransferIn(USDT, msg.sender, _amount);

        uint256 totalTokens = IGovernor(governanceNFT).totalSupply();
        if (totalTokens > 0) {
            uint256 rewardPerTokenIncrease = _amount / totalTokens;
            totalRewardPerToken += rewardPerTokenIncrease;
            totalDistributedRewards += _amount;
        }

        emit DividendDistributed(_amount);
    }

    function claimDividend(uint _tokenId) external nonReentrant {
        require(
            IGovernor(governanceNFT).ownerOf(_tokenId) == msg.sender,
            "Caller is not the token owner"
        );
        uint256 lastClaimed = lastClaimedRewardPerToken[_tokenId];
        uint256 claimableReward = totalRewardPerToken - lastClaimed;

        require(claimableReward > 0, "No reward available");

        lastClaimedRewardPerToken[_tokenId] = totalRewardPerToken;
        doTransferOut(USDT, msg.sender, claimableReward);

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

    // Admin function to set the Merkle root for reward distribution.
    //This will mint scoreNFT
    function mintSentimentScoreNFT(
        address _productId,
        bytes32 _merkleRoot,
        uint _noOfGovernors,
        string memory _scoreNftUri
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ISentimentScore scoreNFT = ISentimentScore(sentimentScore);
        require(
            Assignments[_productId].createdAt != 0,
            "Assignment doesn't exists"
        );
        Assignments[_productId].merkleRoot = _merkleRoot;
        Assignments[_productId].isActive = true;
        Assignments[_productId].noOfGovernors = _noOfGovernors;
        scoreNFT.safeMint(_productId, _scoreNftUri);
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
    function setNewTresury(
        address _newTresury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = payable(_newTresury);
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
        IGovernor govNFT = IGovernor(governanceNFT);
        require(govNFT.balanceOf(msg.sender) == 1, "Not Authorized");
        require(govNFT.ownerOf(_tokenId) == msg.sender, "Not Authorized");

        // get the Gov NFT token id owned by caller
        require(
            Assignments[_productId].isActive,
            "Reward is not active for this Product"
        );
        require(
            INonStandardERC20(USDT).balanceOf(address(this)) >=
                Assignments[_productId].amount,
            "Insufficient Reward"
        );
        require(
            !(Assignments[_productId].claimed[_tokenId]),
            "Already claimed"
        );

        bytes32 merkleRoot = Assignments[_productId].merkleRoot;
        _verifyProof(merkleRoot, proof, _tokenId);

        uint rewardPerGovernor = Assignments[msg.sender].amount /
            Assignments[msg.sender].noOfGovernors;

        Assignments[_productId].claimed[_tokenId] = true;
        govNFT._addProduct(_tokenId, _productId);

        doTransferOut(USDT, msg.sender, rewardPerGovernor);
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

    // Internal function to handle incoming token transfers to the contract.
    function doTransferIn(
        address tokenAddress,
        address from,
        uint256 amount
    ) internal returns (uint256) {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        uint256 balanceBefore = INonStandardERC20(tokenAddress).balanceOf(
            address(this)
        );
        _token.transferFrom(from, address(this), amount);
        bool success;
        assembly {
            switch returndatasize()
            case 0 {
                success := not(0)
            } // Non-standard ERC-20
            case 32 {
                // Compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)
            }
            default {
                revert(0, 0)
            } // Non-compliant ERC-20
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");
        uint256 balanceAfter = INonStandardERC20(tokenAddress).balanceOf(
            address(this)
        );
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;
    }

    // Internal function to handle outgoing token transfers from the contract.
    function doTransferOut(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
        _token.transfer(to, amount);
        bool success;
        assembly {
            switch returndatasize()
            case 0 {
                success := not(0)
            } // Non-standard ERC-20
            case 32 {
                // Compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)
            }
            default {
                revert(0, 0)
            } // Non-compliant ERC-20
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }

    // Admin function to transfer tokens from the contract to the treasury.
    function withdrawDonatedTokens(
        address _tokenAddress,
        uint256 _value
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        doTransferOut(_tokenAddress, treasury, _value);
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
