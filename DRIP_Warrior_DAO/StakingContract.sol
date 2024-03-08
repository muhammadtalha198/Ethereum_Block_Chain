// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}
interface IPancakeRouter01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}


contract Main is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {


     
    IBEP20 public usdtToken;
    IPancakeRouter01 public pancakeRouter; 

    uint256 public registrerationFee;
    
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


    event Withdraw(address _userAddress, uint256 withdrawAmount );
    event Register(address regissteredUser, address referalPerson, uint256 usdtAmount);
    event KGCTransfer(address _from, address _to, uint256 _amount);
    event Stake(address _staker, uint256 _stakeAmount, address _directReferal, uint256 _directreferalBonus);

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }



    function initialize(address initialOwner) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        registrerationFee = 1 ether;


    }


    function registerUserWith(uint256 usdtAmount) external payable whenNotPaused {
        

        require (usdtAmount == registrerationFee || msg.value == registrerationFee, "Invalid fee.");
        require(!userRegistered[msg.sender].registered, "You already registered!");

        userRegistered[msg.sender].hasReferal = true;
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

