
// File: KGC_Platform/Kgc_flattened.sol

pragma solidity ^0.8.20;

contract KGCToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    using SafeMathUpgradeable for uint256;

    IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;

    uint256 public basePercent ;
    uint256 public maxWalletLimit;
    uint256 public _maxBurning;
    uint256 public _totalBurning;
    bool public liquidityadded;
    
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
        _mint(initialOwner,99000 * 1e18);
        _maxBurning = 9000 * 1e18;  
        maxWalletLimit = 10000 * 1e18;

    }

    function GetPairAddress(address _routerAddress, address _usdcAddress) external onlyOwner {
        
        uniswapV2Router = IUniswapV2Router02(_routerAddress);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this),_usdcAddress);

    }

    function _transfer(address from, address to, uint256 value) internal virtual override {
            
        require(!blackListed[from], "You are blacklisted.");
        require(!blackListed[to], "Blacklisted address cannot receive tokens.");

        if(liquidityadded){ 

            if (from != owner() || to != owner() || from != uniswapV2Pair || to != uniswapV2Pair) {
                require(balanceOf(to).add(value) <= maxWalletLimit, "Receiver is exceeding maxWalletLimit");
            }
        }

        if(!liquidityadded){
            
            liquidityadded = true;
            super._transfer(from, to, value);

        }
        else if ( from == owner() || to == owner() || from == uniswapV2Pair || to == uniswapV2Pair) {
            super._transfer(from, to, value);

        } else if ( _totalBurning < _maxBurning){

            uint256 tokensAfterBurn = _burnBasePercentage(value);
            _totalBurning += tokensAfterBurn;
            super._transfer(from, to, value);
            _burn(to, tokensAfterBurn);
        }
        else{
            super._transfer(from, to, value);
        }
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
