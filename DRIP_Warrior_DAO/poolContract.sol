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
            
            __Ownable_init(initialOwner);
            __UUPSUpgradeable_init();

            usdcToken = IBEP20(_usdcAddress);

            devFeePercentage = 1500; // 15 %
            pOPoolPercentage = 3400; // 34 %
            dOPoolPercentage = 1000; // 10 % 
            lOPoolPercentage = 5000; // 50 %
            wOPoolPercentage = 800;  // 8 %
            tdividentPayoutPercentage = 300; // 3 %
            odividentPayoutPercentage = 7500; // 75 %

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

    // plinkoFunds = 0;
    // dripWarriorFunds = 1;
    // liquidWarriorFunds = 2;
    // warriorRushFunds = 4;

    function AddFunds(uint256 _amount, uint256 _projectNo)   external {

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
        
        ( uint256 remainFiftyTPoolAmount,uint256 dividentPayoutOPoolAmount)  = perPoolCalculation();

        uint256 maxlimit;
    
        for(uint256 i = 0; i < noOfUsers; i++){

            uint256 eachSharePercentage = (userRegistered[totalUsers[i]].totalStakedAmount * (10000)) / (totalStakedAmount);
            
            uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
            ownerShipPoolAmount -= eachSendAmount;
           
            uint256 perPersonFromTPool = calculatePercentage(userRegistered[totalUsers[i]].totalStakedAmount, tdividentPayoutPercentage);
            
            maxlimit += perPersonFromTPool;
            treasuryPoolAmount -= perPersonFromTPool;
            
            uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
            userRegistered[totalUsers[i]].receivedAmount += totalSendAmount;

            require(maxlimit < remainFiftyTPoolAmount, "Amount is greater then 50%");
            
            bool success = usdcToken.transfer(totalUsers[i], totalSendAmount);
            require(success, "Transfer failed");

        }

    }

    function perPoolCalculation() private returns(uint256, uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, 5000);
        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, odividentPayoutPercentage);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, 1500);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, 1000);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, 5000);

        treasuryPoolAmount = treasuryPoolAmount + (fifteenPercenntToTPoolAmount);
       
        bool success1 = usdcToken.transfer(maintanceWallte, tenPercenntToMaintenceAmount);
        require(success1, "Transfer failed");

        return (remainFiftyTPoolAmount,dividentPayoutOPoolAmount);
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

    // function set(address _newAddress) external onlyOwner {
    //     require(_newAddress != address(0), "Wrong Addres");

    // }
    // function set(address _newAddress) external onlyOwner {
    //     require(_newAddress != address(0), "Wrong Addres");

    // }
    // function set(address _newAddress) external onlyOwner {
    //     require(_newAddress != address(0), "Wrong Addres");

    // }
    



    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}


// DeV_Fee_Wallet: 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// maintance_wallet: 0x583031D1113aD414F02576BD6afaBfb302140225
// usdc_Holder_address : 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
