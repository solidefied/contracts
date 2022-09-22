/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface INonStandardERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    /// !!! NOTICE !!! transfer does not return a value, in violation of the ERC-20 specification
    function transfer(address dst, uint256 amount) external;

    /// !!! NOTICE !!! transferFrom does not return a value, in violation of the ERC-20 specification
    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external;

    function approve(address spender, uint256 amount)
        external
        returns (bool success);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}

interface IERC721 {
    function mint(address _receiver) external;
}

contract GovernanceSale is ReentrancyGuard, Ownable, Pausable {
    bool public iswhitelis;
    uint256 public CENTS = 10**4;
    uint256 public priceInETH = 1.5 ether;
    uint256 public priceInUSD = 2000 * CENTS;
    address public govAddress;
    address public TREASURY = msg.sender; //replace in prod
    address public USDT;
    address public USDC;
    address public DAI;
    bytes32 public root;

    // address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // 6 decimals
    // address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 decimals
    // address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // 18 decimals

    constructor(
        address _govAddress,
        address _usdtAddress,
        address _usdcAddress,
        address _daiAddress,
        bytes32 _root
    ) {
        govAddress = _govAddress;
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

    function isValid(bytes32[] memory proof, bytes32 leaf)
        public
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, root, leaf);
    }

    function setTreasury(address _treasury) external onlyOwner {
        TREASURY = _treasury;
    }

    //Only Testing
    function setMerkleRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function setPriceETH(uint256 _priceInWei) public onlyOwner {
        priceInETH = _priceInWei;
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

    function buyNFTWithToken(address _purchaseToken, bytes32[] memory proof)
        external
        whenNotPaused
        nonReentrant
        isWhitelisted(proof)
    {
        require(
            _purchaseToken == USDT ||
                _purchaseToken == USDC ||
                _purchaseToken == DAI,
            "Invalid TOKEN"
        );
        uint256 amount;
        if (_purchaseToken == USDT || _purchaseToken == USDC) {
            amount = (priceInUSD * 10**6) / CENTS;
        } else {
            amount = (priceInUSD * 10**18) / CENTS;
        }
        _transferTokensIn(_purchaseToken, msg.sender, amount);
        IERC721(govAddress).mint(msg.sender);
    }

    function _transferTokensIn(
        address tokenAddress,
        address from,
        uint256 amount
    ) private {
        INonStandardERC20 _token = INonStandardERC20(tokenAddress);
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
        require(success, "Transfer failed");
    }

    function _transferTokensOut(
        address tokenAddress,
        address to,
        uint256 amount
    ) private {
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
                // This is a compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0) // Set success = returndata of external call
            }
            default {
                // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "Transfer failed");
    }

    function buyNFTWithETH(bytes32[] memory proof)
        external
        payable
        whenNotPaused
        nonReentrant
        isWhitelisted(proof)
    {
        require(msg.value >= priceInETH, "Incorrect amount");
        IERC721(govAddress).mint(msg.sender);
    }

    function withdrawTokens(address _erc20Token, uint256 _amount)
        external
        onlyOwner
        nonReentrant
        whenPaused
    {
        _transferTokensOut(_erc20Token, TREASURY, _amount);
    }

    function withdrawETH() external onlyOwner nonReentrant whenPaused {
        require(address(this).balance > 0, "Insufficient Balance");
        payable(TREASURY).transfer(address(this).balance);
    }
}
