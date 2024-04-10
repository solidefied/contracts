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
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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

contract ERC20Sale is AccessControl, ReentrancyGuard {
    bytes32 public constant PRODUCT_OWNER = keccak256("PRODUCT_OWNER");

    event ClaimableAmount(address _user, uint256 _claimableAmount);

    uint256 public rate;
    bool public isPrivate; //Closed Sale: true, OpenSale : False // Default is OpenSale
    bytes32 public merkleRoot;
    uint256 public allowedUserBalance;
    INonStandardERC20 public usdt;
    uint256 public hardcap;
    uint256 public softcap;
    bool public isSaleLive;

    address[] public participatedUsers;
    mapping(address => uint256) public claimable;
    address solidefiedAdmin;

    /*
     * @notice Initialize the contract
     * @param _rate: rate of token
     * @param _usdt: usdt token address
     * @param _hardcap: amount to raise
     * @param _allowedUserBalance: max allowed purchase of usdt per user
     * _root = 0 for Open Sale,
     *For Open sale, isPrivate = False, For Closed Sale isPrivate= True
     */
    constructor(
        uint256 _rate,
        address _usdt,
        uint256 _hardcap,
        uint256 _softcap,
        uint256 _allowedUserBalance,
        bytes32 _root,
        bool _isPrivate,
        address _solidefiedAdmin
    ) {
        require(softcap < hardcap, "Softcap should be less than hardcap");
        rate = _rate;
        usdt = INonStandardERC20(_usdt);
        hardcap = _hardcap;
        softcap = _softcap;
        allowedUserBalance = _allowedUserBalance;
        merkleRoot = _root;
        isPrivate = _isPrivate;
        solidefiedAdmin = _solidefiedAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, solidefiedAdmin);
        _grantRole(PRODUCT_OWNER, msg.sender);
    }

    function isValid(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function startSale() external onlyRole(PRODUCT_OWNER) returns (bool) {
        require(!isSaleLive, "Sale is already Live");
        isSaleLive = true;
        return isSaleLive;
    }

    function endSale() external onlyRole(PRODUCT_OWNER) returns (bool) {
        require(isSaleLive, "Sale is already ended");
        isSaleLive = false;
        return isSaleLive;
    }

    /*
     * @notice Change Hardcap
     * @param _hardcap: amount in usdt
     */
    function changeHardcap(uint256 _hardcap) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleLive, "Sale is Live");
        require(softcap < _hardcap, "Hardcap must be greater than softcap");
        hardcap = _hardcap;
    }

    function changeSoftcap(uint256 _softcap) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleLive, "Sale is Live");
        require(_softcap < hardcap, "Softcap should be less than hardcap");
        softcap = _softcap;
    }

    /*
     * @notice Change Rate
     * @param _rate: token rate per usdt
     */
    function changeRate(uint256 _rate) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleLive, "Sale is Live");
        rate = _rate;
    }

    /*
     * @notice Change Allowed user balance
     * @param _allowedUserBalance: amount allowed per user to purchase tokens in usdt
     */
    function changeAllowedUserBalance(
        uint256 _allowedUserBalance
    ) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!isSaleLive, "Sale is Live");
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
    function buyInOpenSale(uint256 _amount) external nonReentrant {
        require(isSaleLive, "Sale is not live");
        require(!isPrivate, "Restricted Sale");
        _buy(_amount);
    }

    function buyInClosedSale(
        uint256 _amount,
        bytes32[] memory proof
    ) external nonReentrant {
        require(isSaleLive, "Sale is not live");
        require(isPrivate, "Restricted sale isn't running");
        require(isValid(proof, keccak256(abi.encodePacked(msg.sender))),"Address isn't listed for sale");
        _buy(_amount);
    }

    function _buy(uint256 _amount) private {
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
        claimable[msg.sender] = userUpdatedBalance;
        participatedUsers.push(msg.sender);
        doTransferIn(address(usdt), msg.sender, _amount);

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
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
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
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        doTransferOut(address(_tokenAddress), _msgSender(), _value);
    }
}