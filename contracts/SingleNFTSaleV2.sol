/*
███████╗ ██████╗ ██╗     ██╗██████╗ ███████╗███████╗██╗███████╗██████╗ 
██╔════╝██╔═══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██║██╔════╝██╔══██╗
███████╗██║   ██║██║     ██║██║  ██║█████╗  █████╗  ██║█████╗  ██║  ██║
╚════██║██║   ██║██║     ██║██║  ██║██╔══╝  ██╔══╝  ██║██╔══╝  ██║  ██║
███████║╚██████╔╝███████╗██║██████╔╝███████╗██║     ██║███████╗██████╔╝
╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝     ╚═╝╚══════╝╚═════╝ 
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    function mintToken(address _receiver) external;
}

contract SingleNFTSaleV2 is ReentrancyGuard, Ownable {
    bool public saleActive;
    bool public whitelistingActive;

    uint256 public priceInETH;
    uint256 public priceInUSD;

    address public nftContract;
    address public TREASURY;
    address public USDT;
    address public USDC;
    address public DAI;

    // address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // 6 decimals
    // address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 decimals
    // address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // 18 decimals

    mapping(address => bool) public whitelist;

    constructor(
        address _nftContract,
        address _treasury,
        uint _priceInETH,
        uint _priceInUSD,
        address _usdtAddress,
        address _usdcAddress,
        address _daiAddress
    ) {
        nftContract = _nftContract;
        TREASURY = _treasury;
        priceInETH = _priceInETH;
        priceInUSD = _priceInUSD; //e.g. $10.22 => 1022
        USDT = _usdtAddress;
        USDC = _usdcAddress;
        DAI = _daiAddress;
    }

    modifier isWhitelisted() {
        require(
            whitelistingActive == false || whitelist[msg.sender],
            "!WHITELISTED"
        );
        _;
    }

    function setTreasury(address _treasury) external onlyOwner {
        TREASURY = _treasury;
    }

    function setPriceETH(uint _priceInETH) public onlyOwner {
        priceInETH = _priceInETH;
    }

    function setPriceUSD(uint _priceInUSD) public onlyOwner {
        priceInUSD = _priceInUSD;
    }

    function setSaleActive(bool _active) external onlyOwner {
        saleActive = _active;
    }

    function setWhitelistingActive(bool _active) external onlyOwner {
        whitelistingActive = _active;
    }

    function addWhitelist(address[] calldata _whitelist) external onlyOwner {
        for (uint256 i; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = true;
        }
    }

    function buyNFTWithToken(address _purchaseToken) external nonReentrant {
        require(saleActive, "!SALE");
        require(
            _purchaseToken == USDT ||
                _purchaseToken == USDC ||
                _purchaseToken == DAI,
            "Invalid TOKEN"
        );
        uint amount;
        if (_purchaseToken == USDT || _purchaseToken == USDC) {
            amount = (priceInUSD * 10**6) / 10**2; // dividing by 10**2 for managing cents
        } else {
            amount = (priceInUSD * 10**18) / 10**2;
        }
        // IERC20(_purchaseToken).transferFrom(
        //     msg.sender,
        //     address(this),
        //     amount
        // );
        _transferTokensIn(_purchaseToken, msg.sender, amount);
        IERC721(nftContract).mintToken(msg.sender);
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
        require(success, "!TRANSFER");
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
        require(success, "!TRANSFER");
    }

    function buyNFTWithETH() external payable nonReentrant {
        require(saleActive, "!SALE");
        require(msg.value == priceInETH, "Incorrect AMOUNT");
        IERC721(nftContract).mintToken(msg.sender);
    }

    function withdrawTokens(address _erc20Token, uint _amount)
        external
        onlyOwner
        nonReentrant
    {
        _transferTokensOut(_erc20Token, TREASURY, _amount);
        // IERC20(_erc20Token).transfer(
        //     TREASURY,
        //     IERC20(_erc20Token).balanceOf(address(this))
        // );
    }

    function withdrawETH() external onlyOwner nonReentrant {
        require(address(this).balance > 0, "!BALANCE");
        payable(TREASURY).transfer(address(this).balance);
    }
}
