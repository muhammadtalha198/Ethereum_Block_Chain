// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Oracle {

    address public owner;
    uint256 public randomNumber;

    constructor(){
        owner = msg.sender; 
    }

    function feedrandomness(uint _randomNumber) external onlyOwner{
        randomNumber = _randomNumber;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner cal call this function.");
        _;
    }
}

contract genarateRandomNumber{

    using SafeMath for uint;
    
    Oracle oracle;
    uint nonce;

    constructor (address _oracleConrtractAddress){
        oracle = Oracle(_oracleConrtractAddress);
    }
    
    uint256 public number;
    
    function call() external  {
        number = numberGenerator();
    }

    function numberGenerator() internal returns(uint){
        uint randomNumber = uint(keccak256(abi.encodePacked(
            nonce,
            oracle.randomNumber(),
            block.timestamp,
            block.difficulty,
            msg.sender))).mod(10); // this will generate the number between 0 to 9
            nonce++;               // if you wana generate between 0 t0 100 add 100 in mode(100) and so on.
            return randomNumber;
    }
}
