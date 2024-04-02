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

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

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

contract RaiseSale is Ownable, Pausable, ReentrancyGuard {
    event ClaimableAmount(address _user, uint256 _claimableAmount);

    uint256 public CENTS = 10 ** 6;
    uint256 public priceInUSD = 5 * CENTS;
    uint256 public MULTIPLIER = 10 ** 18;
    address public TREASURY = msg.sender; //replace in prod

    bool public iswhitelis;
    bytes32 public root;
    uint256 public allowedUserBalance;
    address public USDT;
    address public USDC;
    address public DAI;
    uint256 public hardcap;

    address[] public participatedUsers;
    mapping(address => uint256) public claimable;

    /*
     * @notice Initialize the contract
     * @param _rate: rate of token
     * @param _usdt: usdt token address
     * @param _hardcap: amount to raise
     * @param _allowedUserBalance: max allowed purchase of usdt per user
     */
    constructor(
        uint256 _hardcap, //in 10*4
        uint256 _allowedUserBalance, //in 10*4
        address _usdtAddress,
        address _usdcAddress,
        address _daiAddress,
        bytes32 _root
    ) {
        hardcap = _hardcap;
        allowedUserBalance = _allowedUserBalance;
        USDT = _usdtAddress;
        USDC = _usdcAddress;
        DAI = _daiAddress;
        root = _root;
    }

    modifier isWhitelisted(bytes32[] memory proof) {
        if (iswhitelis) {
            require(
                isValid(proof, keccak256(abi.encodePacked(msg.sender))),
                "Unauthorized"
            );
        }
        _;
    }

    function isValid(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    /*
     * @notice Change Hardcap
     * @param _hardcap: amount in usdt
     */
    function changeHardCap(uint256 _hardcap) public onlyOwner {
        hardcap = _hardcap;
    }

    /*
     * @notice Change Allowed user balance
     * @param _allowedUserBalance: amount allowed per user to purchase tokens in usdt
     */
    function changeAllowedUserBalance(
        uint256 _allowedUserBalance
    ) public onlyOwner {
        allowedUserBalance = _allowedUserBalance;
    }

    /*
     * @notice get total number of participated user
     * @return no of participated user
     */
    function getTotalParticipatedUser() public view returns (uint256) {
        return participatedUsers.length;
    }

    function setPriceUSD(uint256 _priceInUSD) public onlyOwner {
        priceInUSD = _priceInUSD;
    }

    function setWhitelist(bool _status) external onlyOwner {
        iswhitelis = _status;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTreasury(address _treasury) external onlyOwner {
        TREASURY = _treasury;
    }

    function getContractBalance() public view returns (uint256) {
        uint256 totalBal = ((INonStandardERC20(USDT).balanceOf(address(this)) *
            MULTIPLIER) /
            10 ** 6 +
            (INonStandardERC20(USDC).balanceOf(address(this)) * MULTIPLIER) /
            10 ** 6 +
            (INonStandardERC20(DAI).balanceOf(address(this)) * MULTIPLIER) /
            10 ** 18) * CENTS;
        return totalBal;
    }

    /*
     * @notice Buy Token with USDT
     * @param _amount: amount of stable with corrosponding decimal
     */
    function buyToken(
        address _purchaseToken,
        uint256 _amount,
        bytes32[] memory proof
    ) external whenNotPaused nonReentrant isWhitelisted(proof) {
        // user enter amount of ether which is then transfered into the smart contract and tokens to be given is saved in the mapping
        require(
            _purchaseToken == USDT ||
                _purchaseToken == USDC ||
                _purchaseToken == DAI,
            "Invalid TOKEN"
        );

        uint256 rate = (priceInUSD *
            10 ** INonStandardERC20(_purchaseToken).decimals()) / CENTS;
        uint256 tokensPurchased = ((_amount /
            10 ** INonStandardERC20(_purchaseToken).decimals()) * MULTIPLIER) /
            (rate / 10 ** INonStandardERC20(_purchaseToken).decimals());
        uint256 userUpdatedBalance = claimable[msg.sender] + tokensPurchased;
        require(
            (_amount * MULTIPLIER * CENTS) /
                10 ** INonStandardERC20(_purchaseToken).decimals() +
                getContractBalance() <=
                hardcap * MULTIPLIER,
            "Hardcap reached"
        );

        require(
            userUpdatedBalance *
                (rate / 10 ** INonStandardERC20(_purchaseToken).decimals()) *
                CENTS <=
                allowedUserBalance * MULTIPLIER,
            "Exceeded allowance"
        );

        doTransferIn(address(_purchaseToken), msg.sender, _amount);
        claimable[msg.sender] = userUpdatedBalance;
        participatedUsers.push(msg.sender);
        emit ClaimableAmount(msg.sender, tokensPurchased);
    }

    //testing

    function buyTokenUSDT(
        uint256 _amount,
        bytes32[] memory proof
    ) external whenNotPaused nonReentrant isWhitelisted(proof) {
        // user enter amount of ether which is then transfered into the smart contract and tokens to be given is saved in the mapping
        uint256 tokensPurchased = (_amount * MULTIPLIER) / priceInUSD;
        uint256 userUpdatedBalance = claimable[msg.sender] + tokensPurchased;
        require(
            (_amount * MULTIPLIER) / 10 ** 6 + getContractBalance() <=
                hardcap * MULTIPLIER,
            "Hardcap reached"
        );

        require(
            userUpdatedBalance * priceInUSD <= allowedUserBalance * MULTIPLIER,
            "Exceeded allowance"
        );

        doTransferIn(address(USDT), msg.sender, _amount);
        claimable[msg.sender] = userUpdatedBalance;
        participatedUsers.push(msg.sender);
        emit ClaimableAmount(msg.sender, tokensPurchased);
    }

    /*
     * @notice get user list
     * @return userAddress: user address list
     * @return amount : user wise claimable amount list
     */
    function getUsersList(
        uint256 startIndex,
        uint256 endIndex
    )
        external
        view
        returns (address[] memory userAddress, uint256[] memory amount)
    {
        uint256 length = endIndex - startIndex;
        address[] memory _userAddress = new address[](length);
        uint256[] memory _amount = new uint256[](length);

        for (uint256 i = startIndex; i < endIndex; i++) {
            address user = participatedUsers[i];
            uint256 listIndex = i - startIndex;
            _userAddress[listIndex] = user;
            _amount[listIndex] = claimable[user];
        }

        return (_userAddress, _amount);
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

    /*
     * @notice funds withdraw
     * @param _value: usdt value to transfer from contract to owner
     */
    function fundsWithdrawal(
        address _tokenAddress,
        uint256 _value
    ) external onlyOwner whenPaused nonReentrant {
        doTransferOut(address(_tokenAddress), TREASURY, _value);
    }

    /*
     * @notice funds withdraw
     * @param _tokenAddress: token address to transfer
     * @param _value: token value to transfer from contract to owner
     */
    function withdrawETH() external onlyOwner nonReentrant whenPaused {
        require(address(this).balance > 0, "Insufficient Balance");
        payable(TREASURY).transfer(address(this).balance);
    }

    receive() external payable {}
}
