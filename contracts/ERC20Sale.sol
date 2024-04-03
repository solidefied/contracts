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

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! transfer does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! transferFrom does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///
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

contract ERC20Sale is AccessControl {
    event ClaimableAmount(address _user, uint256 _claimableAmount);
    uint256 public rate; //rate = (1 / 1 token price in usd) * (10**12)
    bool public presaleOver;
    IERC20 public usdt; //0xc2132d05d31c914a87c6611c10748aeb04b58e8f
    mapping(address => uint256) public claimable;
    uint256 public hardcap; //  hardcap = usd value * (10**6)
    uint256 public totalRaised;
    uint256 public totalTokenPurchase;

    address[] public participatedUsers;

    constructor(uint256 _rate, address _usdt, uint256 _hardcap) {
        rate = _rate;
        usdt = IERC20(_usdt);
        presaleOver = true;
        hardcap = _hardcap;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier isPresaleOver() {
        require(presaleOver == true, "The  Sale is not over yet");
        _;
    }

    function changeHardCap(
        uint256 _hardcap
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        hardcap = _hardcap;
    }

    function changeRate(uint256 _rate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rate = _rate;
    }

    function getTotalParticipatedUser() public view returns (uint256) {
        return participatedUsers.length;
    }

    function endPresale() external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        presaleOver = true;
        return presaleOver;
    }

    function startPresale()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        presaleOver = false;
        return presaleOver;
    }

    function buyTokenWithUSDT(uint256 _amount) external {
        // user enter amount of ether which is then transfered into the smart contract and tokens to be given is saved in the mapping
        require(presaleOver == false, "Sale  is over");
        uint256 tokensPurchased = _amount * rate;
        uint256 userUpdatedBalance = claimable[msg.sender] + tokensPurchased;
        require(
            _amount + (usdt.balanceOf(address(this))) <= hardcap,
            "Hardcap reached"
        );
        // for USDT
        doTransferIn(address(usdt), msg.sender, _amount);
        claimable[msg.sender] = userUpdatedBalance;
        participatedUsers.push(msg.sender);
        totalRaised = totalRaised + _amount;
        totalTokenPurchase = totalTokenPurchase + tokensPurchased;
        emit ClaimableAmount(msg.sender, tokensPurchased);
    }

    function getUsersList(
        uint startIndex,
        uint endIndex
    )
        external
        view
        returns (address[] memory userAddress, uint[] memory amount)
    {
        uint length = endIndex - startIndex;
        address[] memory _userAddress = new address[](length);
        uint[] memory _amount = new uint[](length);

        for (uint i = startIndex; i < endIndex; i++) {
            address user = participatedUsers[i];
            uint listIndex = i - startIndex;
            _userAddress[listIndex] = user;
            _amount[listIndex] = claimable[user];
        }

        return (_userAddress, _amount);
    }

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

    function fundsWithdrawal(
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) isPresaleOver {
        doTransferOut(address(usdt), _msgSender(), _value);
    }

    function transferAnyERC20Tokens(
        address _tokenAddress,
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        doTransferOut(address(_tokenAddress), _msgSender(), _value);
    }
}
