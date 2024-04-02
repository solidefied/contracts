// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint256);

    /// !!! NOTICE !!! transfer does not return a value, in violation of the ERC-20 specification
    function transfer(address dst, uint256 amount) external;

    /// !!! NOTICE !!! transferFrom does not return a value, in violation of the ERC-20 specification
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

contract RewardDistribution is ERC20, Ownable {
    struct Assignment {
        mapping(address => bool) govList;
        bytes32 merkleRoot;
        uint256 amount;
        bool isActive;
    }
    uint256 assessmentCost = 2000;
    mapping(address => Assignment) Assignments;
    address public USDT;
    address public Treasury;

    constructor(address _usdt, address _treasury) ERC20("AirDropToken", "ADT") {
        USDT = _usdt;
        Treasury = _treasury;
    }

    event AssignmentCreated(address _user, uint256 claimableAmount);
    event MerkleRootAdded(address productOwner, bytes32 merkleRoot);
    event RewardsClaimed(
        address productOwner,
        address userAddress,
        uint256 rewardAmount
    );

    function createAssignment(uint256 _amount) external {
        require(
            _amount >= assessmentCost * INonStandardERC20(USDT).decimals(),
            "Invalid Amount"
        );

        doTransferIn(USDT, msg.sender, _amount);
        Assignments[msg.sender].amount = _amount;
        emit AssignmentCreated(msg.sender, _amount);
    }

    // Call this at the time of Score creation

    function setMerkleRoot(
        address _productOwner,
        bytes32 _merkleRoot
    ) external onlyOwner {
        Assignments[_productOwner].merkleRoot = _merkleRoot;
        Assignments[_productOwner].isActive = true;
        emit MerkleRootAdded(_productOwner, _merkleRoot);
    }

    function setAssessmentCost(uint256 _newCost) external onlyOwner {
        assessmentCost = _newCost;
    }

    function setNewTresury(address _newTresury) external onlyOwner {
        Treasury = _newTresury;
    }

    function setRewardClaim(
        address _productOwner,
        bool _status
    ) external onlyOwner {
        Assignments[_productOwner].isActive = _status;
    }

    function claimReward(
        address _productOwner,
        bytes32[] calldata proof,
        uint256 amount
    ) external {
        //Reward Claim is Active
        require(
            Assignments[_productOwner].isActive,
            "Reward is not active for this Product"
        );
        // Check if reward pool is not usdt left for the last user to claim
        require(
            (Assignments[_productOwner].amount >= amount) &&
                (INonStandardERC20(USDT).balanceOf(address(this)) >= amount),
            "Reward Pool is empty"
        );

        // check if already claimed
        require(
            !(Assignments[_productOwner].govList[msg.sender]),
            "Already claimed"
        );

        // verify proof
        bytes32 merkleRoot = Assignments[_productOwner].merkleRoot;
        _verifyProof(merkleRoot, proof, amount, msg.sender);

        // set reward claimed for the user
        Assignments[_productOwner].govList[msg.sender] = true;
        Assignments[_productOwner].amount -= amount;

        // Send funds
        doTransferOut(USDT, msg.sender, amount);
        emit RewardsClaimed(_productOwner, msg.sender, amount);
    }

    function _verifyProof(
        bytes32 _merkleRoot,
        bytes32[] memory proof,
        uint256 amount,
        address addr
    ) private pure {
        bytes32 leaf = keccak256(abi.encode(addr, amount));
        require(MerkleProof.verify(proof, _merkleRoot, leaf), "Invalid proof");
    }

    /*
     * @notice do transfer in - tranfer token to contract
     * @param tokenAddress: token address to transfer in contract
     * @param from : user address from where to transfer token to contract
     * @param amount : amount to trasnfer
     */
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
                // This is a non-standard ERC-20
                success := not(0) // set success to true
            }
            case 32 {
                // This is a compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0) // Set success = returndata of external call
            }
            default {
                // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");
        // Calculate the amount that was actually transferred
        uint256 balanceAfter = INonStandardERC20(tokenAddress).balanceOf(
            address(this)
        );
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore; // underflow already checked above, just subtract
    }

    /*
     * @notice do transfer out - tranfer token from contract
     * @param tokenAddress: token address to transfer from contract
     * @param to : user address to where transfer token from contract
     * @param amount : amount to trasnfer
     */
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
                // This is a non-standard ERC-20
                success := not(0) // set success to true
            }
            case 32 {
                // This is a complaint ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0) // Set success = returndata of external call
            }
            default {
                // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }

    function skim(address _tokenAddress, uint256 _value) external onlyOwner {
        doTransferOut(address(_tokenAddress), Treasury, _value);
    }

    function skimETH() external onlyOwner {
        require(address(this).balance > 0, "Insufficient Balance");
        payable(Treasury).transfer(address(this).balance);
    }

    receive() external payable {}
}
