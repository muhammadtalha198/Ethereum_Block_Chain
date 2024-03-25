
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


contract PoolContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    IBEP20 public usdcToken;

    address  public maintanceWallte;
    address  public usdcHolderWallet;
    address  public DevFeeWallet;
    
    uint256 public TreasuryPool;
    uint256 public OwnerShipPool;

    struct UserRegistered{
        bool registered;
        uint256 withdrawedAmount;
        uint256 totalStakedAmount;

    }

    mapping(address => UserRegistered) public userRegistered;

    event FundTransfer (address sender,uint256 usdcAmount);
    event Withdraw (address recipient, uint256 usdcAmount);
    event FundTransferToPool (address sender,uint256 usdcAmount);
    
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _usdcAddress) initializer public {
        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        usdcToken = IBEP20(_usdcAddress);
    }



    function StakeTokens(uint256 _amount) external  {
        
        require(_amount != 0,"invalid _amount!");
        require(msg.sender != address(0), "invalid Address!");

        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].totalStakedAmount += _amount;

        bool success =usdcToken.transferFrom(msg.sender,usdcHolderWallet,_amount);
        require(success, "Transfer failed");

        emit FundTransfer(msg.sender, _amount);

    }


    function PlinkoFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        require(msg.sender != address(0), "invalid Address!");

        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount);
        require(success, "Transfer failed");

    }

    function DripWarriorFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        require(msg.sender != address(0), "invalid Address!");

        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount);
        require(success, "Transfer failed");

    }

    function WithdrawAmount(uint256 _amount) external onlyOwner {
        
        require(_amount != 0,"invalid _amount!");
        
        bool success = usdcToken.transfer(msg.sender,_amount);
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, _amount);
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
