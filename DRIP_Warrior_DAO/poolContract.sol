// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}


contract PoolContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
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

    uint256 public tdividentPayoutPercentage;
    uint256 public odividentPayoutPercentage;
    uint256 public flowToTreasuryPercentage;
    uint256 public maintainceFeePercentage;

    uint256 public noOfUsers;

    struct UserRegistered{

        bool registered;
        uint256 receivedAmount;
        uint256 totalStakedAmount;
    }

    mapping(uint256 => address) public totalUsers;
    mapping(address => UserRegistered) public userRegistered;
    
    event AddFunds(uint256 _amount, uint256 _projectNo);
    event Withdraw (address recipient, uint256 usdcAmount);
    event WalletCchanged(address _owner, address _newAddress);
    event PercentageChanged(address _owner, uint256 _newPercentage);
    event StakeTokens (address sender, address recepient,uint256 usdcAmount);

    
    
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
            
            
            __Ownable_init(initialOwner);
            __UUPSUpgradeable_init();

            usdcToken = IBEP20(_usdcAddress);

            devFeePercentage = 1500; // 15 %
            pOPoolPercentage = 3400; // 34 %
            dOPoolPercentage = 1000; // 10 % 
            lOPoolPercentage = 5000; // 50 %
            wOPoolPercentage = 800;  // 8 %
            tdividentPayoutPercentage = 5000; // 50 %
            odividentPayoutPercentage = 7500; // 75 %
            
            flowToTreasuryPercentage = 1500; // 15 %
            maintainceFeePercentage = 1000; // 10 % 

            maintanceWallte = _maintanceWallte;
            usdcHolderWallet = _usdcHolderWallet;
            devFeeWallet = _DevFeeWallet;
    }



    function stakeTokens(uint256 _amount) external  {
        
        require(_amount != 0,"invalid _amount!");

        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].totalStakedAmount += _amount;
        totalUsers[noOfUsers] = msg.sender;
        totalStakedAmount += _amount;
        noOfUsers++;

        bool success =usdcToken.transferFrom(msg.sender,usdcHolderWallet,_amount);
        require(success, "Transfer failed");

        emit StakeTokens(msg.sender,usdcHolderWallet, _amount);

    }

    // plinkoFunds = 0;
    // dripWarriorFunds = 1;
    // liquidWarriorFunds = 2;
    // warriorRushFunds = 4;

    function addFunds(uint256 _amount, uint256 _projectNo)   external {

        require(_amount != 0,"invalid _amount!");

        uint256 devFee;

        if(_projectNo == 0){
            
             devFee = calculateFees(_amount, devFeePercentage, pOPoolPercentage);
        } 
        else if(_projectNo == 1) {
            
             devFee = calculateFees(_amount, devFeePercentage, dOPoolPercentage); 
        }
        else if(_projectNo == 2){

             devFee = calculateFees(_amount, devFeePercentage, lOPoolPercentage);
        }
        else {

             devFee = calculateFees(_amount, devFeePercentage, wOPoolPercentage);
        }


        bool success = usdcToken.transferFrom(msg.sender,devFeeWallet,devFee);
        require(success, "Transfer failed");
        
        bool success1 = usdcToken.transferFrom(msg.sender,address(this),_amount - (devFee));
        require(success1, "Transfer failed");

        emit AddFunds(_amount,_projectNo);
        

    }


    function calculateFees(uint256 _amount, uint256 _devFeePercentage, uint256 _poolPercentage) private returns(uint256) {
        
        uint256 devFee = calculatePercentage(_amount, _devFeePercentage);
        uint256 ownerShipFee = calculatePercentage(_amount, _poolPercentage);

        uint256 tPoolPercentage = 10000;
        tPoolPercentage = tPoolPercentage - (_devFeePercentage + (_poolPercentage));
        
        uint256 treasuryFee = calculatePercentage(_amount, tPoolPercentage);

        totalDevFee = totalDevFee + (devFee);
        ownerShipPoolAmount = ownerShipPoolAmount + (ownerShipFee);
        treasuryPoolAmount = treasuryPoolAmount + (treasuryFee);

        return devFee;
    }



    function WeeklyTransfer() external  {
        
        ( uint256 remainFiftyTPoolAmount,uint256 dividentPayoutOPoolAmount, uint256 perPersonFromTPool)  = perPoolCalculation();

        uint256 maxlimit;
    
        for(uint256 i = 0; i < noOfUsers; i++){

            uint256 eachSharePercentage = (userRegistered[totalUsers[i]].totalStakedAmount * (10000)) / (totalStakedAmount);
            
            uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
            ownerShipPoolAmount -= eachSendAmount;
                       
            maxlimit += eachSendAmount;
            treasuryPoolAmount -= perPersonFromTPool;
            
            uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
            userRegistered[totalUsers[i]].receivedAmount += totalSendAmount;

            require(maxlimit < remainFiftyTPoolAmount, "Amount is greater then 50%");
            
            bool success = usdcToken.transfer(totalUsers[i], totalSendAmount);
            require(success, "Transfer failed");

        }

    }

    function perPoolCalculation() private returns(uint256, uint256,uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, 5000);
        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, odividentPayoutPercentage);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, flowToTreasuryPercentage);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, maintainceFeePercentage);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, tdividentPayoutPercentage);

        uint256 perPersonFromTPool = remainFiftyTPoolAmount/noOfUsers;

        treasuryPoolAmount = treasuryPoolAmount + (fifteenPercenntToTPoolAmount);
       
        bool success1 = usdcToken.transfer(maintanceWallte, tenPercenntToMaintenceAmount);
        require(success1, "Transfer failed");

        return (remainFiftyTPoolAmount,dividentPayoutOPoolAmount,perPersonFromTPool);
    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }

    function WithdrawAmount(uint256 _amount) external onlyOwner {
        
        require(_amount != 0,"invalid _amount!");
        
        bool success = usdcToken.transfer(msg.sender,_amount);
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    function settdividentPayoutPercentage(uint256 _newPerccentage) external onlyOwner {
        
        require(_newPerccentage != 0, "Wrong percentage");
        tdividentPayoutPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, tdividentPayoutPercentage);

    }
    
    function setodividentPayoutPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        odividentPayoutPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, odividentPayoutPercentage);
    }

    function setdOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        dOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, dOPoolPercentage);

    }
    function setlOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        lOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, lOPoolPercentage);

    }
    function setwOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        wOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, wOPoolPercentage);

    }
    function setdevFeePercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        devFeePercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, devFeePercentage);
    }

    function setflowToTreasuryPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        flowToTreasuryPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, flowToTreasuryPercentage);
    }

    function setmaintainceFeePercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        maintainceFeePercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, maintainceFeePercentage);
    }

    
    function setmaintanceWallte(address _newAddress) external onlyOwner {
       
        require(_newAddress != address(0), "Wrong Addres");
        maintanceWallte = _newAddress;

        emit WalletCchanged(msg.sender, maintanceWallte);
    }

    function setusdcHolderWallet(address _newAddress) external onlyOwner {
        
        require(_newAddress != address(0), "Wrong Addres");
        usdcHolderWallet = _newAddress;

        emit WalletCchanged(msg.sender, usdcHolderWallet);

    }

    function setdevFeeWallet(address _newAddress) external onlyOwner {
        
        require(_newAddress != address(0), "Wrong Addres");
        devFeeWallet = _newAddress;

        emit WalletCchanged(msg.sender, devFeeWallet);

    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}


// DeV_Fee_Wallet: 0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915
// maintance_wallet: 0xCA6e763716eA3a3e425baD2954a65BBb411e5fBC
// usdc_Holder_address : 0xbEc540D2840BF6c5b52FC98f61e760E6fb1B2659
