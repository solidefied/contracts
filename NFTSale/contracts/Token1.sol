// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token1 is ERC20 {
    constructor() ERC20("Test 1", "TT1") {
        _mint(msg.sender, 7 * 10000**18);
    }
}
