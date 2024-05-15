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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Sale is AccessControl, ReentrancyGuard {
    bytes32 public constant PRODUCT_OWNER = keccak256("PRODUCT_OWNER");

    event ClaimableAmount(address _user, uint256 _claimableAmount);
    event Refund(address _user, uint256 _amount);

    uint256 private rate; // pass the value in 10** 18 terms
    bool public isPrivate; //Closed Sale: true, OpenSale : False // Default is OpenSale
    bytes32 public merkleRoot;
    uint256 public allowedUserBalance; // pass the value in 10** 18 terms
    IERC20 public paymentToken;
    uint256 private hardcap; // pass the value in 10** 18 terms
    uint256 private softcap; // pass the value in 10** 18 terms
    bool public isSaleLive;
    bool public softCapReached;
    address payable private treasury;

    address[] public participatedUsers;
    mapping(address => uint256) public claimable;
    address solidefiedAdmin;

    /*
     * @notice Initialize the contract
     * @param _rate: rate of token
     * @param _paymentToken: payment token address
     * @param _hardcap: amount to raise
     * @param _softcap: amount to reach for the sale to be successful
     * @param _allowedUserBalance: max allowed purchase of payment token per user
     * @param _root: Merkle root for whitelist (0 for open sale)
     * @param _isPrivate: true for closed sale, false for open sale
     * @param _solidefiedAdmin: admin address
     * @param _treasury: treasury address
     */
    constructor(
        uint256 _rate,
        address _paymentToken,
        uint256 _hardcap,
        uint256 _softcap,
        uint256 _allowedUserBalance,
        bytes32 _root,
        bool _isPrivate,
        address _solidefiedAdmin,
        address _treasury
    ) {
        require(
            _softcap <= _hardcap,
            "Softcap should be less than or equal to hardcap"
        );
        rate = _rate;
        paymentToken = IERC20(_paymentToken);
        hardcap = _hardcap;
        softcap = _softcap;
        allowedUserBalance = _allowedUserBalance;
        merkleRoot = _root;
        isPrivate = _isPrivate;
        solidefiedAdmin = _solidefiedAdmin;
        treasury = payable(_treasury);
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

        // Check if soft cap is reached
        if (paymentToken.balanceOf(address(this)) >= softcap) {
            softCapReached = true;
        }

        return isSaleLive;
    }

    /*
     * @notice Change Hardcap
     * @param _hardcap: amount in payment tokens
     */
    function changeHardcap(uint256 _hardcap) public onlyRole(PRODUCT_OWNER) {
        require(!isSaleLive, "Sale is Live");
        require(
            softcap <= _hardcap,
            "Softcap should be less than or equal to hardcap"
        );
        hardcap = _hardcap;
    }

    function changeSoftcap(uint256 _softcap) public onlyRole(PRODUCT_OWNER) {
        require(!isSaleLive, "Sale is Live");
        require(
            _softcap <= hardcap,
            "Softcap should be less than or equal to hardcap"
        );
        softcap = _softcap;
    }

    /*
     * @notice Change Rate
     * @param _rate: token rate per payment token
     */
    function changeRate(uint256 _rate) public onlyRole(PRODUCT_OWNER) {
        require(!isSaleLive, "Sale is Live");
        rate = _rate;
    }

    /*
     * @notice Change Allowed user balance
     * @param _allowedUserBalance: amount allowed per user to purchase tokens in payment tokens
     */
    function changeAllowedUserBalance(
        uint256 _allowedUserBalance
    ) public onlyRole(PRODUCT_OWNER) {
        require(!isSaleLive, "Sale is Live");
        allowedUserBalance = _allowedUserBalance;
    }

    /*
     * @notice get total number of participated users
     * @return number of participated users
     */
    function getTotalParticipatedUser() public view returns (uint256) {
        return participatedUsers.length;
    }

    /*
     * @notice Buy Token with payment tokens
     * @param _amount: amount of payment tokens
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
        require(
            isValid(proof, keccak256(abi.encodePacked(msg.sender))),
            "Unauthorized"
        );
        _buy(_amount);
    }

    function _buy(uint256 _amount) private {
        uint256 tokensPurchased = (_amount * rate) / 10 ** 18;
        uint256 userUpdatedBalance = claimable[msg.sender] + tokensPurchased;
        require(
            _amount + paymentToken.balanceOf(address(this)) <= hardcap,
            "Hardcap reached"
        );

        // Ensure the user does not exceed the allowed balance
        require(userUpdatedBalance <= allowedUserBalance, "Exceeded allowance");

        if (claimable[msg.sender] == 0) {
            participatedUsers.push(msg.sender);
        }
        claimable[msg.sender] = userUpdatedBalance;

        require(
            paymentToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

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
     * @notice Withdraw funds
     * @param _value: amount to transfer from contract to treasury
     */
    function fundsWithdrawal(
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(softCapReached, "Softcap not reached, cannot withdraw funds");
        require(
            IERC20(paymentToken).transfer(treasury, _value),
            "Token transfer failed"
        );
    }

    /*
     * @notice Transfer any ERC20 tokens
     * @param _tokenAddress: token address to transfer
     * @param _value: token value to transfer from contract to treasury
     */
    function transferAnyERC20Tokens(
        address _tokenAddress,
        uint256 _value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(softCapReached, "Softcap not reached, cannot transfer tokens");
        require(
            IERC20(_tokenAddress).transfer(treasury, _value),
            "Token transfer failed"
        );
    }

    /*
     * @notice Refund users if softcap is not reached
     */
    function refund() external nonReentrant {
        require(!softCapReached, "Softcap reached, refunds are not available");
        uint256 amount = claimable[msg.sender];
        require(amount > 0, "No claimable amount to refund");

        claimable[msg.sender] = 0;
        require(
            paymentToken.transfer(msg.sender, amount),
            "Refund transfer failed"
        );

        emit Refund(msg.sender, amount);
    }
}
