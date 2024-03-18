// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}


contract Main is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {


    IBEP20 public usdtToken;
    AggregatorV3Interface public priceFeedUsdt_to_BNB;
    AggregatorV3Interface public priceFeed_DAI_to_BNB;

    uint256 public minBnbAmount;
    
    address payable public maintanceWallte;
    address payable public bnbHolderWallet;
    address  public usdtHolderWallet;
    address  public tokenHolderWallet;
    
    uint256 public DaoTreasuryPool;
    uint256 public DaoOwnerPool;


    struct UserRegistered{
        bool registered;
        uint256 noOfStakes;
        uint256 totalReward;
        uint256 withdrawedAmount;
        uint256 totalStakedAmount;

    }
    

    struct StakeInfo {
        bool staked;
        uint256 stakeAmount;
    }

    mapping(address => UserRegistered) public userRegistered;
    mapping(address => mapping (uint256 => StakeInfo)) public stakeInfo;


    event Register(address regissteredUser, uint256 usdtAmount);
    event Withdraw(address _userAddress, uint256 withdrawAmount );
    event KGCTransfer(address _from, address _to, uint256 _amount);
    event Stake(address _staker, uint256 _stakeAmount, address _directReferal, uint256 _directreferalBonus);

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // USDT / BNB = 0xD5c40f5144848Bd4EF08a9605d860e727b991513 mainneet BSC

   // DAI / BNB = 0x0630521aC362bc7A19a4eE44b57cE72Ea34AD01c:  testnet bsc 


    function initialize(address initialOwner,address _priceFeedUsdt_to_BNB,address _priceFeed_DAI_to_BNB) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        minBnbAmount = 1 ether;
        priceFeedUsdt_to_BNB = AggregatorV3Interface(_priceFeedUsdt_to_BNB);
        priceFeedUsdt_to_BNB = AggregatorV3Interface(_priceFeed_DAI_to_BNB);


    }

    // Function to fetch the latest BNB/USD price from Chainlink oracle
    function getLatestBnbPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeedUsdt_to_BNB.latestRoundData();
        require(price > 0, "Invalid BNB/USD price from oracle");
        return uint256(price);
    }
    // Function to fetch the latest BNB/USD price from Chainlink oracle
    function GetpriceFeed_DAI_to_BNB() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed_DAI_to_BNB.latestRoundData();
        require(price > 0, "Invalid BNB/USD price from oracle");
        return uint256(price);
    }


    function registerUserWith(uint256 usdtAmount) external payable whenNotPaused {
        
        // uint256 latestBnbPrice = getLatestBnbPrice();
        uint256 latestBnbPrice = GetpriceFeed_DAI_to_BNB();
        
        uint256 minUsdtAmount = minBnbAmount * latestBnbPrice; // Minimum USDT equivalent

        require(msg.value >= minBnbAmount || msg.value * latestBnbPrice >= minUsdtAmount, "Insufficient payment");
        require(!userRegistered[msg.sender].registered, "You already registered!");

        userRegistered[msg.sender].registered = true;

        if (msg.value == 1 ether) {

            (bool success, ) = payable(bnbHolderWallet).call{value: msg.value}("");
            require(success, "Transfer failed");

            emit Register(msg.sender, msg.value);

        } else {
    
            bool success =usdtToken.transferFrom(msg.sender,usdtHolderWallet,usdtAmount);
            require(success, "Transfer failed");

            emit Register(msg.sender, usdtAmount);
        }

    }

    Stake





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
}
