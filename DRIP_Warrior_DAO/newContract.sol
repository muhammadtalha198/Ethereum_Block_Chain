
// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

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
    address  public devFeeWallet;

    uint256 public devFeePercentage;
    uint256 public totalDevFee;


    uint256 public pOPoolPercentage;
    uint256 public dOPoolPercentage;
    uint256 public lOPoolPercentage;
    uint256 public wOPoolPercentage;
    
    
    uint256 public treasuryPoolAmount;
    uint256 public ownerShipPoolAmount;
    uint256 public totalStakedAmount;

    uint256 public noOfUsers;

    struct UserRegistered{

        bool registered;
        uint256 receivedAmount;
        uint256 totalStakedAmount;
    }

    mapping(uint256 => address) public totalUsers;
    mapping(address => UserRegistered) public userRegistered;
    
    event FundTransfer (address sender, address recepient,uint256 usdcAmount);
    event Withdraw (address recipient, uint256 usdcAmount);
    event FundTransferToPool (address sender,uint256 usdcAmount);
    
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner, 
        address _usdcAddress,
        address _maintanceWallte,
        address _usdcHolderWallet,
        address _DevFeeWallet

        ) initializer public {
            
            __Pausable_init();
            __Ownable_init(initialOwner);
            __UUPSUpgradeable_init();

            usdcToken = IBEP20(_usdcAddress);

            devFeePercentage = 1500; // 15 %
            pOPoolPercentage = 3400; // 34 %
            dOPoolPercentage = 1000; // 10 % 
            lOPoolPercentage = 5000; // 50 %
            wOPoolPercentage = 800;  // 8 %

            maintanceWallte = _maintanceWallte;
            usdcHolderWallet = _usdcHolderWallet;
            devFeeWallet = _DevFeeWallet;
    }



    function StakeTokens(uint256 _amount) external  {
        
        require(_amount != 0,"invalid _amount!");

        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].totalStakedAmount += _amount;
        totalUsers[noOfUsers] = msg.sender;
        totalStakedAmount += _amount;
        noOfUsers++;

        bool success =usdcToken.transferFrom(msg.sender,usdcHolderWallet,_amount);
        require(success, "Transfer failed");

        emit FundTransfer(msg.sender,usdcHolderWallet, _amount);

    }


    function plinkoFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");

        uint256 devFee = pFundsCaculations(_amount);

        bool success = usdcToken.transferFrom(msg.sender,devFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount.sub(devFee));
        require(success1, "Transfer failed");

    }

    function pFundsCaculations(uint256 _amount) private returns(uint256){
        
        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, pOPoolPercentage);
        uint256 treasuryFee = calculatePercentage(_amount, pTPoolPercentage);

        totalDevFee = totalDevFee.add(devFee);
        ownerShipPoolAmount = ownerShipPoolAmount.add(ownerShipFee);
        treasuryPoolAmount = treasuryPoolAmount.add(treasuryFee);

        return devFee;
    }

    function dripWarriorFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        
        uint256 devFee = dWFundsCalculations(_amount);

        bool success = usdcToken.transferFrom(msg.sender,devFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount.sub(devFee));
        require(success1, "Transfer failed");


    }

    function dWFundsCalculations(uint256 _amount) private returns(uint256) {

        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, dOPoolPercentage);
        
        uint256 tPoolPercentage = 10000;
        tPoolPercentage = tPoolPercentage.sub((devFeePercentage.add(dOPoolPercentage)));
        
        uint256 treasuryFee = calculatePercentage(_amount, tPoolPercentage);

        totalDevFee = totalDevFee.add(devFee);
        ownerShipPoolAmount = ownerShipPoolAmount.add(ownerShipFee);
        treasuryPoolAmount = treasuryPoolAmount.add(treasuryFee);

        return devFee;
    }


    function liquidWarriorFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        
        uint256 devFee = dWFundsCalculations(_amount);

        bool success = usdcToken.transferFrom(msg.sender,devFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount.sub(devFee));
        require(success1, "Transfer failed");


    }

    function lWFundsCalculations(uint256 _amount) private returns(uint256) {

        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, dOPoolPercentage);
        
        uint256 tPoolPercentage = 10000;
        tPoolPercentage = tPoolPercentage.sub((devFeePercentage.add(dOPoolPercentage)));
        
        uint256 treasuryFee = calculatePercentage(_amount, tPoolPercentage);

        totalDevFee = totalDevFee.add(devFee);
        ownerShipPoolAmount = ownerShipPoolAmount.add(ownerShipFee);
        treasuryPoolAmount = treasuryPoolAmount.add(treasuryFee);

        return devFee;
    }

    function warriorRushFunds(uint256 _amount)   external {

        require(_amount != 0,"invalid _amount!");
        
        uint256 devFee = dWFundsCalculations(_amount);

        bool success = usdcToken.transferFrom(msg.sender,devFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount.sub(devFee));
        require(success1, "Transfer failed");


    }

    function wRFundsCalculations(uint256 _amount) private returns(uint256) {

        uint256 devFee = calculatePercentage(_amount, devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, dOPoolPercentage);
        
        uint256 tPoolPercentage = 10000;
        tPoolPercentage = tPoolPercentage.sub((devFeePercentage.add(dOPoolPercentage)));
        
        uint256 treasuryFee = calculatePercentage(_amount, tPoolPercentage);

        totalDevFee = totalDevFee.add(devFee);
        ownerShipPoolAmount = ownerShipPoolAmount.add(ownerShipFee);
        treasuryPoolAmount = treasuryPoolAmount.add(treasuryFee);

        return devFee;
    }



    function WeeklyTransfer() external  {
        
        ( uint256 remainFiftyTPoolAmount,uint256 dividentPayoutOPoolAmount)  = perPoolCalculation();

        uint256 maxlimit;
    
        for(uint256 i = 0; i < noOfUsers; i++){

            uint256 eachSharePercentage = (userRegistered[totalUsers[i]].totalStakedAmount.mul(10000)).div(totalStakedAmount);
            
            uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
            userRegistered[totalUsers[i]].receivedAmount += eachSendAmount;
            
            ownerShipPoolAmount -= eachSendAmount;
           
            uint256 perPersonFromTPool = calculatePercentage(userRegistered[totalUsers[i]].totalStakedAmount, 300);
            
            maxlimit += perPersonFromTPool;
            treasuryPoolAmount -= perPersonFromTPool;

            require(maxlimit < remainFiftyTPoolAmount, "Amount is greater then 50%");
            
            bool success = usdcToken.transfer(totalUsers[i], eachSendAmount);
            require(success, "Transfer failed");
            
            bool success1 = usdcToken.transfer(totalUsers[i], perPersonFromTPool);
            require(success1, "Transfer failed");

        }

    }

    function perPoolCalculation() private returns(uint256, uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, 5000);
        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, 7500);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, 1500);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, 1000);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, 5000);

        treasuryPoolAmount = treasuryPoolAmount.add(fifteenPercenntToTPoolAmount);
       
        bool success1 = usdcToken.transfer(maintanceWallte, tenPercenntToMaintenceAmount);
        require(success1, "Transfer failed");

        return (remainFiftyTPoolAmount,dividentPayoutOPoolAmount);
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


// DeV_Fee_Wallet: 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// maintance_wallet: 0x583031D1113aD414F02576BD6afaBfb302140225
// usdc_Holder_address : 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
