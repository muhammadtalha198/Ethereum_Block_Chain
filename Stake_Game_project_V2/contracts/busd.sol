// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract BusdToken is ERC20 {
    constructor() ERC20("BUSD Token", "FBUSD") {
        _mint(msg.sender, 10000 * 10**decimals());
    }
}

