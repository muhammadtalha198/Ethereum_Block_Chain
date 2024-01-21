// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";


contract KGCToken is ERC20, ERC20Burnable, Ownable {
    
    uint256 public basePercent = 10;
    uint256 public maxBuyLimit;
    uint256 public maxWalletLimit;
    uint256 public _maxBurning;
    uint256 public _totalBurning;


    mapping(address => bool) private blackListed;
    
    constructor(address initialOwner)
        ERC20("KGCToken", "KGC")
        Ownable(initialOwner){

            _mint(initialOwner,99000 * 1e18 );
            _maxBurning = 9000 * 1e18; 
        
            maxBuyLimit = 10000 * 1e18; 
            maxWalletLimit = 10000 * 1e18; 
    }

    function _transfer(address _from, address _to, uint256 _amount) internal virtual override  {
        
        if (_from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        
        require(!blackListed[_from], "You are blacklisted.");
        require(!blackListed[_to], "blacklisted address canot be able to recieve tokens.");

        require(_amount <= maxBuyLimit, "You are exceeding maxBuyLimit");
        require(balanceOf(_to) + _amount <= maxWalletLimit,"Receiver are exceeding maxWalletLimit");

        uint256 tokensAfterBurn;
	
        if( _totalBurning < _maxBurning){

             tokensAfterBurn = _burnBasePercentage(_amount);
            _totalBurning += tokensAfterBurn;
        }

        _update(_from, _to, _amount);
        _burn(_to,tokensAfterBurn);
        
    }


    function _burnBasePercentage(uint256 _amount) private view returns (uint256)  {

        return ((_amount * basePercent)/(10000)); 
    }

    function updateMaxBuyLimit(uint256 maxBuy) external onlyOwner {
        maxBuyLimit = maxBuy * 1e18;
    }

    function updateMaxWalletlimit(uint256 amount) external onlyOwner {
        maxWalletLimit = amount * 1e18;
    }
    
    function updateMaxBurning(uint256 burnAmount) external onlyOwner {
      
        uint256 burnToken = burnAmount  * 1e18;    
        if(burnToken < totalSupply()){      
            _maxBurning = burnToken;
        }
    }

    function addInBlackList(address account) public onlyOwner {
        blackListed[account] = true;
    }
    
    function removeFromBlackList(address account) public onlyOwner {
        blackListed[account] = false;
    }

    function addBulkInBlacklist(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            blackListed[accounts[i]] = true;
        }
    }

    function removeBulkInBlacklist(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            blackListed[accounts[i]] = false;
        }
    }

    function isBlackListed(address _address) public view returns( bool _blacklisted){
        
        if(blackListed[_address] == true){
            return true;
        }
        else{
            return false;
        }
    }




}

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
