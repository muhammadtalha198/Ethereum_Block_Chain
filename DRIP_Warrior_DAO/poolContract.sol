// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;


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


    uint256 public sSOPoolPercentage;
    uint256 public dMOPoolPercentage;
    uint256 public lWOPoolPercentage;
    uint256 public wROPoolPercentage;
    
    
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
        uint256 receiveFromTreasury;
        uint256 receiveFromOwneerShip;
        uint256 totalStakedAmount;
    }

    mapping(uint256 => address) public totalUsers;
    mapping(address => bool) public alreadyAdded;
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
            sSOPoolPercentage = 3400; // 34 %
            dMOPoolPercentage = 1000; // 10 % 
            lWOPoolPercentage = 5000; // 50 %
            wROPoolPercentage = 800;  // 8 %
            tdividentPayoutPercentage = 5000; // 50 %
            odividentPayoutPercentage = 7500; // 75 %
            
            flowToTreasuryPercentage = 1500; // l
            maintainceFeePercentage = 1000; // 10 % 

            maintanceWallte = _maintanceWallte;
            usdcHolderWallet = _usdcHolderWallet;
            devFeeWallet = _DevFeeWallet;
    }



    function stakeTokens(uint256 _amount) external  {
        
        require(_amount != 0,"invalid _amount!");

        userRegistered[msg.sender].registered = true;
        userRegistered[msg.sender].totalStakedAmount += _amount;
       
        if(!alreadyAdded[msg.sender]){
            totalUsers[noOfUsers] = msg.sender;
            noOfUsers++;
        }

        totalStakedAmount += _amount;

        bool success =usdcToken.transferFrom(msg.sender,usdcHolderWallet,_amount);
        require(success, "Transfer failed");

        emit StakeTokens(msg.sender,usdcHolderWallet, _amount);

    }

    // sSOPoolPercentage = 0;
    // dMOPoolPercentage = 1;
    // lWOPoolPercentage = 2;
    // wROPoolPercentage = 3;

    function addFunds(uint256 _amount, uint256 _projectNo)   external {

        require(_amount != 0,"invalid _amount!");

        uint256 devFee;

        if(_projectNo == 0){
            
             devFee = calculateFees(_amount, devFeePercentage, sSOPoolPercentage);
        } 
        else if(_projectNo == 1) {
            
             devFee = calculateFees(_amount, devFeePercentage, dMOPoolPercentage); 
        }
        else if(_projectNo == 2){

             devFee = calculateFees(_amount, devFeePercentage, lWOPoolPercentage);
        }
        else {

             devFee = calculateFees(_amount, devFeePercentage, wROPoolPercentage);
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

            userRegistered[totalUsers[i]].receiveFromTreasury = perPersonFromTPool;
            userRegistered[totalUsers[i]].receiveFromOwneerShip = eachSendAmount;
            
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

        require(noOfUsers > 0, "no users!");
        
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
    
    function setpOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        sSOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, sSOPoolPercentage);
    }

    function setdOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        dMOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, dMOPoolPercentage);

    }
    function setlOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        lWOPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, lWOPoolPercentage);

    }
    function setwOPoolPercentage(uint256 _newPerccentage) external onlyOwner {
        require(_newPerccentage != 0, "Wrong percentage");
        wROPoolPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, wROPoolPercentage);

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


// maintance_wallet: 0xCA6e763716eA3a3e425baD2954a65BBb411e5fBC
// usdc_Holder_address : 0xbEc540D2840BF6c5b52FC98f61e760E6fb1B2659
// DeV_Fee_Wallet: 0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915
