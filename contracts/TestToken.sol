// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract NFTSale is AccessControl, ReentrancyGuard {
    bytes32 public constant PRODUCT_OWNER = keccak256("PRODUCT_OWNER");

    IERC20 public paymentToken;
    uint256 public rate;
    uint256 public softcap;
    uint256 public hardcap;
    bool public saleIsActive = false;
    bytes32 public merkleRoot;
    uint256 public mintCapPerWallet;
    bool public isPrivate; //Closed Sale: true, OpenSale : False // Default is OpenSale
    address solidefiedAdmin;
    address[] public participatedUsers;

    uint FACTOR = 10 ** 4;

    event SaleStarted();
    event SaleEnded();
    event TokensPurchased(address buyer, uint256 amount);

    constructor(
        address _paymentToken,
        uint256 _rate,
        uint256 _softcap,
        uint256 _hardcap,
        bool _isPrivate,
        uint256 _mintCapPerWallet,
        bytes32 _merkleRoot,
        address _solidefiedAdmin
    ) {
        paymentToken = IERC20(_paymentToken);
        rate = _rate;
        softcap = _softcap;
        hardcap = _hardcap;
        isPrivate = _isPrivate;
        mintCapPerWallet = _mintCapPerWallet;
        merkleRoot = _merkleRoot;
        solidefiedAdmin = _solidefiedAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, solidefiedAdmin);
        _grantRole(PRODUCT_OWNER, msg.sender);
    }

    function startSale() external onlyRole(PRODUCT_OWNER) {
        require(!saleIsActive, "Sale already active");
        saleIsActive = true;
        emit SaleStarted();
    }

    function endSale() external onlyRole(PRODUCT_OWNER) {
        require(saleIsActive, "Sale not active");
        saleIsActive = false;
        emit SaleEnded();
    }

    function isValid(
        bytes32[] memory proof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function changeSoftcap(uint256 _softcap) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!saleIsActive, "Sale is Live");
        // require(_softcap < totalSupply, "Softcap should be less than total Supply");
        softcap = _softcap;
    }

    /*
     * @notice Change Rate
     * @param _rate: token rate per usdt
     */
    function changeRate(uint256 _rate) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!saleIsActive, "Sale is Live");
        rate = _rate;
    }

    /*
     * @notice Change Allowed user balance
     * @param _allowedUserBalance: amount allowed per user to purchase tokens in usdt
     */
    function changeMintCapPerWallet(
        uint256 _mintCapPerWallet
    ) public onlyRole(PRODUCT_OWNER) {
        //Product Owner can not change this when the sale is live.
        require(!saleIsActive, "Sale is Live");
        mintCapPerWallet = _mintCapPerWallet;
    }

    /*
     * @notice get total number of participated user
     * @return no of participated user
     */
    function getTotalParticipatedUser() public view returns (uint256) {
        return participatedUsers.length;
    }

    function buyTokens(
        uint256 amount,
        bytes32[] calldata proof
    ) external virtual;
}
