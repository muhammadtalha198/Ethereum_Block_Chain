// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



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

    function transfer(address to, uint256 value) public virtual override returns (bool) {
            
        address owner = _msgSender();

        require(!blackListed[owner], "You are blacklisted.");
        require(!blackListed[to], "blacklisted address canot be able to recieve tokens.");

        require(value <= maxBuyLimit, "You are exceeding maxBuyLimit");
        require(balanceOf(to) + value <= maxWalletLimit,"Receiver are exceeding maxWalletLimit");

        uint256 tokensAfterBurn;
	
        if( _totalBurning < _maxBurning){

             tokensAfterBurn = _burnBasePercentage(value);
            _totalBurning += tokensAfterBurn;
        }

        _burn(to,tokensAfterBurn);
        _transfer(owner, to, value);
        return true;
    }

     function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        
        address spender = _msgSender();

        _spendAllowance(from, spender, value);

        require(!blackListed[from], "You are blacklisted.");
        require(!blackListed[to], "blacklisted address canot be able to recieve tokens.");

        require(value <= maxBuyLimit, "You are exceeding maxBuyLimit");
        require(balanceOf(to) + value <= maxWalletLimit,"Receiver are exceeding maxWalletLimit");

        uint256 tokensAfterBurn;
	
        if( _totalBurning < _maxBurning){

             tokensAfterBurn = _burnBasePercentage(value);
            _totalBurning += tokensAfterBurn;
        }

    
        _burn(to,tokensAfterBurn);

        _transfer(from, to, value);
        return true;
    }



    function _burnBasePercentage(uint256 value) private view returns (uint256)  {

        return ((value * basePercent)/(10000)); 
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

    // function rescueAnyBEP20Tokens(
    //     address _tokenAddr,
    //     address to,
    //     uint256 value
    // ) public onlyOwner {
    //     IBEP20(_tokenAddr).transfer(to, value);
    // }


}

// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
