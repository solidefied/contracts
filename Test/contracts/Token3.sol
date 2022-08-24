// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token3 is ERC20 {
    constructor() ERC20("Test 3", "TT3") {
        _mint(msg.sender, 9 * 10000**18);
    }
}
