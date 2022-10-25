// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Arena is ERC20 {
    
    address public _owner;
    
    constructor() ERC20 ("ARENA Token","FARN") {
        _mint(msg.sender, 10000 * (10 ** uint256(decimals())));
        _owner = msg.sender;

    }

}