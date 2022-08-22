// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token2 is ERC20 {
    constructor() ERC20("Test 2", "TT2") {
        _mint(msg.sender, 8 * 10000**18);
    }
}
