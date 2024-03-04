// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";


contract MyToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    using SafeMathUpgradeable for uint256;

    uint256 public basePercent ;
    uint256 public maxWalletLimit;
    uint256 public _maxBurning;
    uint256 public _totalBurning;
    
    mapping(address => bool) private blackListed;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __ERC20_init("KGCToken", "KGC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();


        basePercent = 10;
        _mint(initialOwner,99000 * 1e18 );
        _maxBurning = 9000 * 1e18;  
        maxWalletLimit = 10000 * 1e18;
    }


    function transfer(address to, uint256 value) public virtual override whenNotPaused returns (bool) {
            
        address owner = _msgSender();
        bool callSuccess = transferCall(owner,to,value);
        require(callSuccess, "Transfer failed");
        
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual override whenNotPaused returns (bool) {
        
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        bool callSuccess = transferCall(from,to,value);
        require(callSuccess, "Transfer failed");
        
        return true;
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        _approve(owner, spender, currentAllowance.add(value), true);
        
        return true;
    }

    function transferCall(address from, address to, uint256 value) private returns (bool){
        
        require(!blackListed[from], "You are blacklisted.");
        require(!blackListed[to], "blacklisted address canot be able to recieve tokens.");
        require(balanceOf(to).add(value) <= maxWalletLimit,"Receiver are exceeding maxWalletLimit");

        uint256 tokensAfterBurn;
	
        if( _totalBurning < _maxBurning){

             tokensAfterBurn = _burnBasePercentage(value);
            _totalBurning += tokensAfterBurn;
            _transfer(from, to, value);
            _burn(to,tokensAfterBurn);
        }
        else{
            _transfer(from, to, value);
        }

        return true;
    }

    function burn(uint256 value) public virtual override onlyOwner { 
       
        require(_totalBurning.add( value) < _maxBurning,"Burning Limit exceeds!"); 
        _totalBurning += value;
        _burn(_msgSender(), value);
    }
    
    function burnFrom(address account, uint256 value) public virtual override onlyOwner {
        
        require(_totalBurning.add(value) < _maxBurning,"Burning Limit exceeds!"); 
        
        _totalBurning += value;
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    function decreaseAllowance(address spender, uint256 value) external {
        _spendAllowance(msg.sender, spender, value); 
    }

    function _burnBasePercentage(uint256 value) private view returns (uint256)  {

        return ((value.mul(basePercent)).div(10000)); 
    }

    function updateMaxWalletlimit(uint256 amount) external onlyOwner {
        maxWalletLimit = amount;
    }
    
    function updateMaxBurning(uint256 burnAmount) external onlyOwner {    
        
        if(burnAmount < totalSupply()){      
            _maxBurning = burnAmount;
        }
    }

    function addInBlackList(address account) external onlyOwner {
        blackListed[account] = true;
    }
    
    function removeFromBlackList(address account) external  onlyOwner {
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

    function isBlackListed(address _address) external view returns( bool _blacklisted){
        
        if(blackListed[_address] == true){
            return true;
        }
        else{
            return false;
        }
    }

    function mint(address to, uint256 amount) public 
    
     {
        _mint(to, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._update(from, to, value);
    }
}

