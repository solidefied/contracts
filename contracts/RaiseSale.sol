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
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

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

contract RaiseSale is Ownable(msg.sender), Pausable, ReentrancyGuard {
    event ClaimableAmount(address _user, uint256 _claimableAmount);

    uint256 public rate;
    bool public iswhitelis;
    bytes32 public root;
    uint256 public allowedUserBalance;
    INonStandardERC20 public usdt;
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
        uint256 _rate,
        address _usdt,
        uint256 _hardcap,
        uint256 _allowedUserBalance,
        bytes32 _root
    ) {
        rate = _rate;
        usdt = INonStandardERC20(_usdt);
        hardcap = _hardcap;
        allowedUserBalance = _allowedUserBalance;
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
     * @notice Change Rate
     * @param _rate: token rate per usdt
     */
    function changeRate(uint256 _rate) public onlyOwner {
        rate = _rate;
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

    /*
     * @notice Buy Token with USDT
     * @param _amount: amount of usdt
     */
    function buyTokenWithUSDT(
        uint256 _amount
    ) external whenNotPaused nonReentrant {
        // user enter amount of ether which is then transfered into the smart contract and tokens to be given is saved in the mapping

        uint256 tokensPurchased = _amount * rate;
        uint256 userUpdatedBalance = claimable[msg.sender] + tokensPurchased;
        require(
            _amount + usdt.balanceOf(address(this)) <= hardcap,
            "Hardcap reached"
        );
        // for USDT
        require(
            userUpdatedBalance / rate <= allowedUserBalance,
            "Exceeded allowance"
        );
        doTransferIn(address(usdt), msg.sender, _amount);
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
        uint256 _value
    ) external onlyOwner whenPaused nonReentrant {
        doTransferOut(address(usdt), _msgSender(), _value);
    }

    /*
     * @notice funds withdraw
     * @param _tokenAddress: token address to transfer
     * @param _value: token value to transfer from contract to owner
     */
    function transferAnyERC20Tokens(
        address _tokenAddress,
        uint256 _value
    ) external onlyOwner whenPaused nonReentrant {
        doTransferOut(address(_tokenAddress), _msgSender(), _value);
    }
}
