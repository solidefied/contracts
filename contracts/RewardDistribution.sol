/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Importing OpenZeppelin contracts for ERC20 token functionality, Merkle proof verification, and ownership management.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

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
contract RewardDistribution is ERC20, AccessControl {
    // Structure to hold assignment details including governance list, Merkle root, amount, and active status.
    struct Assignment {
        mapping(address => bool) govList;
        bytes32 merkleRoot;
        uint256 amount;
        bool isActive;
    }
    uint256 assessmentCost = 2000; // The cost required for assessment.
    mapping(address => Assignment) Assignments; // Mapping from product owner to their assignment.
    address public USDT; // Address of the USDT token.
    address public Treasury; // Address of the Treasury to collect fees or unused funds.

    // Events for logging activities on the blockchain.
    event AssignmentCreated(address _user, uint256 claimableAmount);
    event MerkleRootAdded(address productOwner, bytes32 merkleRoot);
    event RewardsClaimed(
        address productOwner,
        address userAddress,
        uint256 rewardAmount
    );

    // Constructor to set initial values for USDT token address and Treasury.
    constructor(address _usdt, address _treasury) ERC20("AirDropToken", "ADT") {
        USDT = _usdt;
        Treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Function to create an assignment by product owners.
    function createAssignment(uint256 _amount) external {
        require(
            _amount >= assessmentCost * INonStandardERC20(USDT).decimals(),
            "Invalid Amount"
        );
        doTransferIn(USDT, msg.sender, _amount);
        Assignments[msg.sender].amount = _amount;
        emit AssignmentCreated(msg.sender, _amount);
    }

    // Admin function to set the Merkle root for reward distribution.
    function setMerkleRoot(
        address _productOwner,
        bytes32 _merkleRoot
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Assignments[_productOwner].merkleRoot = _merkleRoot;
        Assignments[_productOwner].isActive = true;
        emit MerkleRootAdded(_productOwner, _merkleRoot);
    }

    // Admin function to update the assessment cost.
    function setAssessmentCost(
        uint256 _newCost
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assessmentCost = _newCost;
    }

    // Admin function to update the treasury address.
    function setNewTresury(
        address _newTresury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Treasury = _newTresury;
    }

    // Admin function to enable or disable reward claims for a product owner.
    function setRewardClaim(
        address _productOwner,
        bool _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Assignments[_productOwner].isActive = _status;
    }

    // Function for users to claim their rewards.
    function claimReward(
        address _productOwner,
        bytes32[] calldata proof,
        uint256 amount
    ) external {
        require(
            Assignments[_productOwner].isActive,
            "Reward is not active for this Product"
        );
        require(
            (Assignments[_productOwner].amount >= amount) &&
                (INonStandardERC20(USDT).balanceOf(address(this)) >= amount),
            "Reward Pool is empty"
        );
        require(
            !(Assignments[_productOwner].govList[msg.sender]),
            "Already claimed"
        );

        bytes32 merkleRoot = Assignments[_productOwner].merkleRoot;
        _verifyProof(merkleRoot, proof, amount, msg.sender);

        Assignments[_productOwner].govList[msg.sender] = true;
        Assignments[_productOwner].amount -= amount;

        doTransferOut(USDT, msg.sender, amount);
        emit RewardsClaimed(_productOwner, msg.sender, amount);
    }

    // Private function to verify Merkle proof for claim verification.
    function _verifyProof(
        bytes32 _merkleRoot,
        bytes32[] memory proof,
        uint256 amount,
        address addr
    ) private pure {
        bytes32 leaf = keccak256(abi.encode(addr, amount));
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
    function skim(
        address _tokenAddress,
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        doTransferOut(_tokenAddress, Treasury, _value);
    }

    // Admin function to transfer ETH from the contract to the treasury.
    function skimETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance > 0, "Insufficient Balance");
        payable(Treasury).transfer(address(this).balance);
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}
}
