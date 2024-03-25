// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}


contract PoolContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    using SafeMathUpgradeable for uint256;
    IBEP20 public usdcToken;

    address  public maintanceWallte;
    address  public usdcHolderWallet;
    address  public DevFeeWallet;

    uint256 public totalDFevFee;

    uint256 treasuryPoolPercentage;
    uint256 devFeePercentage;
    
    uint256 plinkoOwnershipPoolPercentage;
    uint256 dripOwnershipPoolPercentage;
    
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

        treasuryPoolPercentage = 5100; // 51 %
        devFeePercentage = 1500; //15 %
        plinkoOwnershipPoolPercentage = 3400; // 34 %
        dripOwnershipPoolPercentage = 1000; // 10% 


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

        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, plinkoOwnershipPoolPercentage);
        uint256 treasuryFee = calculatePercentage(_amount, treasuryPoolPercentage);

        totalDFevFee = totalDFevFee.add(devFee);
        OwnerShipPool = OwnerShipPool.add(ownerShipFee);
        TreasuryPool = TreasuryPool.add(treasuryFee);

        bool success = usdcToken.transferFrom(msg.sender,DevFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount);
        require(success1, "Transfer failed");

    }

    function DripWarriorFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        require(msg.sender != address(0), "invalid Address!");
        
        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, plinkoOwnershipPoolPercentage);
        
        uint256 treasuryPoolPercentahge = 10000;
        treasuryPoolPercentahge = treasuryPoolPercentahge.sub((devFee.add(dripOwnershipPoolPercentage)));
        
        uint256 treasuryFee = calculatePercentage(_amount, treasuryPoolPercentahge);

        totalDFevFee = totalDFevFee.add(devFee);
        OwnerShipPool = OwnerShipPool.add(ownerShipFee);
        TreasuryPool = TreasuryPool.add(treasuryFee);

        bool success = usdcToken.transferFrom(msg.sender,DevFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount);
        require(success1, "Transfer failed");


    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount.mul(percentageNumber).div(10000);
        
        return serviceFee;
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
