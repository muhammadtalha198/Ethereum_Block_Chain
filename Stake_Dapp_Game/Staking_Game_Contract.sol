import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


// SPDX-License-Identifier: MIT 
pragma solidity 0.8.9;



interface IBEP20 {

        function balanceOf(address account) external view returns (uint256);
        function transfer(address recipient, uint256 amount) external returns (bool);
        function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
        function sell(uint256 amount) external;
    }


contract StakingContract {

    using SafeMath for uint256;
    
    IBEP20 public genToken;
    IBEP20 public arenaToken;
    IBEP20 public busdToken;

    struct Stake {

        uint256 amount;
        uint256 genBonus;
        uint256 areenaBonus;
    }
        
    struct Player {

        uint256 battleCount;
        uint256 walletLimit;
        uint256 activeBattles;
        uint256 winingBattles;
        uint256 losingBattles;
        uint256 totalGenBonus;
        uint256 referalAmount;
        uint256 totalArenaTokens;
        uint256 totalAmountStaked;
        uint256 genAmountPlusBonus;
        mapping(uint256 => Stake) battleRecord;
    }

    struct Battle {

        bool active;
        bool joined;
        bool leaved;
        bool completed;
        address loser;
        address winner;
        address joiner;
        address creator;
        uint256 battleTime;
        uint256 endingTime;
        uint256 stakeAmount;
        uint256 startingTime;
        uint256 riskPercentage;
        uint256 creatorStartingtime;
    }

    struct referenceInformation{
        bool creatorRefered;
        bool joinerRefered;
        uint256 creatorReferalAmount;
        uint256 joinerReferalAmount;
        address creatorReferalAddress;
        address joinerReferalAddress;
    }

    address public owner;
    uint256 public battleId;
    uint256 public totalAreena;
    uint256 public afterPrice = 15;
    uint256 public initialPrice = 10;
    uint256 public genRewardPercentage;
    uint256 public genRewardMultiplicationValue;
    uint256 public areenaInCirculation;
    uint256 public areenaBosterPrice;

    uint256 private minimumStake = 25;
    uint256[5] public stakeOptions = [25, 100, 250, 500, 1000];
    uint256[5] public riskOptions = [25, 50, 75];

    mapping(uint256 => Battle) public battles;
    mapping(address => Player) public players;
    mapping(address => uint256) public genLastTransaction;
    mapping(address => uint256) public areenaLastTransaction;
    mapping(uint256 => referenceInformation) public referalPerson;
    mapping(uint256 => mapping(address => uint256)) public stakeCount;
    mapping(address => mapping(address => bool)) public alreadyBatteled;


    address private treasuryWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private areenaWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;
    address private busdWallet = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe;

 

    event createBattle(address indexed battleCreator, uint256 stakeAmount, uint256 indexed battleId);
    event joinBattle(address indexed battleJoiner, uint256 stakeAmount, uint256 indexed battleId);
    event referalInfo(address joinerRefaralPerson, address creatorReferalPerson, uint256 joinerReferalAmount, uint256 creatorReferalAmount);
    event winnerDetails(uint256 indexed winnerStakedAmount, uint256 winnerGenBonus, uint256 indexed winnerAreenaBonus);
    event loserDetails(uint256 indexed looserStakedAmount, uint256 looserGenBonus);
    
    constructor(address _genToken, address _arenaToken, address _busdToken){
        owner = msg.sender;
        genToken = IBEP20(_genToken);
        busdToken = IBEP20(_busdToken);
        arenaToken = IBEP20(_arenaToken);
        genRewardPercentage = 416667000000000; //0.000416667%
        genRewardMultiplicationValue = 1e9;
        areenaBosterPrice = 200*1e18;      //200 
        totalAreena = 10000*1e18;
    }

    
    
    function checkOption (uint256 amount) internal view returns(uint256){
        uint256 value;
        for(uint256 i =0; i < 5; i++){
            if(amount == stakeOptions[i]){
                value = stakeOptions[i];
                break;
            }
        }
        if (value !=0){
            return value;
        }
        else{
            return amount;
        }
    }

    
    function CreateBattle(uint256 _amount, uint256 _riskPercentage, address _referalPerson) external {

        uint256 stakeAmount = checkOption (_amount);
        stakeAmount = stakeAmount.mul(1e18);

        require(stakeAmount >= minimumStake, "You must stake atleast 25 Gen tokens to enter into the battle.");
        require((genToken.balanceOf(msg.sender) + players[msg.sender].genAmountPlusBonus) >= stakeAmount,"You does not have sufficent amount of gen Token.");
        require(_riskPercentage == riskOptions[0] || _riskPercentage == riskOptions[1] || _riskPercentage == riskOptions[2], "Please chose the valid risk percentage.");
        require(msg.sender != address(0), "Player address canot be zero.");
        require(owner != address(0), "Owner address canot be zero.");
         
        battleId++;
            
        Battle storage battle = battles[battleId];

        if(genToken.balanceOf(msg.sender) < stakeAmount){
            
            uint256 amountFromAddress = genToken.balanceOf(msg.sender); 
            genToken.transferFrom(msg.sender, address(this), amountFromAddress);
        }
        else{
            genToken.transferFrom(msg.sender, address(this), stakeAmount);
        }

        if(_referalPerson != 0x0000000000000000000000000000000000000000){

            referalPerson[battleId].creatorRefered = true;
            referalPerson[battleId].creatorReferalAddress = _referalPerson;
        }

        battle.stakeAmount = stakeAmount;
        battle.creator = msg.sender;
        battle.riskPercentage = _riskPercentage;

        battle.creatorStartingtime = block.timestamp;

        emit createBattle(msg.sender,stakeAmount,battleId);
        
    }

    
    function JoinBattle(uint256 _amount, uint256 _battleId, address joinerReferalPerson) public {

        Battle storage battle = battles[_battleId];
        Player storage player = players[msg.sender];
        battle.joiner = msg.sender;

        uint256 stakeAmount = _amount.mul(1e18);
        
        require(!battle.joined && !battle.leaved, "You can not join this battle. This battle may be already joined or completed."); 
        require(!alreadyBatteled[battle.creator][battle.joiner], "You can not create or join new battles with same person.");    
        require(!alreadyBatteled[battle.joiner][battle.creator], "You can not create or join new battles with same person.");  
        require(stakeAmount == battle.stakeAmount,"Enter the exact amount of tokens to be a part of this battle.");
        require((genToken.balanceOf(msg.sender) + players[msg.sender].genAmountPlusBonus) >= stakeAmount,"You does not have sufficent amount of gen Token.");
        require(msg.sender != address(0), "Player address canot be zero.");
        require(owner != address(0), "Owner address canot be zero.");
        
        

        uint256 creatorDeductedAmount = calculateCreatorPercentage(stakeAmount);
        uint256 creatorAfterDeductedAmount = stakeAmount - creatorDeductedAmount;
 
        uint256 joinerDeductedAmount = calculateJoinerPercentage(stakeAmount);
        uint256 joinerAfterDeductedAmount = stakeAmount - joinerDeductedAmount;

       

        players[battle.creator].battleCount++;
        if(battle.creator != battle.joiner){
            player.battleCount++;
        }


        stakeCount[battleId][battle.creator] = players[battle.creator].battleCount;
        stakeCount[battleId][battle.joiner] = players[battle.joiner].battleCount;

        if(genToken.balanceOf(msg.sender) < stakeAmount){

            uint256 amountFromAddress = genToken.balanceOf(msg.sender); 
            genToken.transferFrom(msg.sender, address(this), amountFromAddress);
        }
        else{

            genToken.transferFrom(msg.sender, address(this), stakeAmount);
        }

        if(joinerReferalPerson != 0x0000000000000000000000000000000000000000){
           
           referalPerson[_battleId].joinerRefered = true;
           referalPerson[_battleId].joinerReferalAddress = joinerReferalPerson;
            
            uint256 joinerReferalAmount = calculateReferalPercentage(stakeAmount);
            referalPerson[_battleId].joinerReferalAmount = joinerReferalAmount;
            
            
            genToken.transfer(joinerReferalPerson,joinerReferalAmount);

            uint256 sendJoinerDeductionAmount = joinerDeductedAmount - joinerReferalAmount;
            genToken.transfer(treasuryWallet, sendJoinerDeductionAmount);
            


            player.referalAmount += joinerReferalAmount;
        }
        else{
            genToken.transfer(treasuryWallet, joinerDeductedAmount);
        }

        if(referalPerson[_battleId].creatorRefered){
            
            uint256 creatorReferalAmount = calculateReferalPercentage(stakeAmount);
            referalPerson[_battleId].creatorReferalAmount = creatorReferalAmount;

            address creatorReferalPerson;
            creatorReferalPerson = referalPerson[_battleId].creatorReferalAddress;
           
            genToken.transfer(creatorReferalPerson,creatorReferalAmount);

            uint256 sendCreatorDeductionAmount = creatorDeductedAmount - creatorReferalAmount;
            genToken.transfer(treasuryWallet, sendCreatorDeductionAmount);
            
            players[battle.creator].referalAmount += creatorReferalAmount;
        }
        else{

            genToken.transfer(treasuryWallet, creatorDeductedAmount);
        }

        battle.startingTime = block.timestamp;
        battle.active = true;
        battle.joined = true;
        
        players[battle.creator].activeBattles++;
        if(battle.creator != battle.joiner){
            player.activeBattles++;
        }

        alreadyBatteled[battle.creator][battle.joiner] = true;
        alreadyBatteled[battle.joiner][battle.creator] = false;

        
        player.totalAmountStaked += joinerAfterDeductedAmount;
        players[battle.creator].totalAmountStaked +=  creatorAfterDeductedAmount;
        players[battle.creator].battleRecord[stakeCount[battleId][battle.creator]].amount = creatorAfterDeductedAmount;
        players[battle.joiner].battleRecord[ stakeCount[battleId][battle.joiner]].amount = joinerAfterDeductedAmount;     

        emit joinBattle(msg.sender,stakeAmount,battleId);

        emit referalInfo(
            joinerReferalPerson, 
            referalPerson[_battleId].creatorReferalAddress,
            referalPerson[_battleId].joinerReferalAmount,
            referalPerson[_battleId].creatorReferalAmount
        );
    }


    function LeaveBattle(uint256 count) public {

       Battle storage battle = battles[count];

        require(msg.sender == battle.creator || msg.sender == battle.joiner, "You must be a part of a battle before leaving it.");
        require(!battle.leaved, "You canot join this battle because battle creator Already leaved.");
        require(msg.sender != address(0), "Player address canot be zero.");
        require(owner != address(0), "Owner address canot be zero.");

        if(!battle.joined){
                ////////////////48hours///////////////////////////
            require(block.timestamp > (battle.creatorStartingtime + 1 minutes),"You have to wait atleast 3 minutes to leave battle if no one join the battle.");

            uint256 tokenAmount = battle.stakeAmount;
            
            uint256 deductedAmount = calculateSendBackPercentage(tokenAmount);
            
            tokenAmount = tokenAmount - deductedAmount;
            players[battle.creator].genAmountPlusBonus += tokenAmount;
            genToken.transfer(treasuryWallet, deductedAmount); 
           
            battle.leaved = true; 

        }
        else{

            require( !battle.completed,"This battle is already ended.");
            
            if(msg.sender == battle.creator){
                battle.loser = battle.creator;
                battle.winner = battle.joiner;
            }
            else{
                battle.loser = battle.joiner;
                battle.winner = battle.creator; 
            }

            
            uint256 losertokenAmount = players[battle.loser].battleRecord[players[battle.loser].battleCount].amount;
            uint256 winnertokenAmount = players[battle.winner].battleRecord[players[battle.winner].battleCount].amount;

            uint256 totalMinutes =  calculateTotalMinutes(block.timestamp, battle.startingTime);
 
            uint256 loserGenReward = calculateRewardInGen(losertokenAmount, totalMinutes);
            uint256 winnerGenReward = calculateRewardInGen(winnertokenAmount, totalMinutes);
     
            uint256 riskDeductionFromLoser = calculateRiskPercentage(loserGenReward, battle.riskPercentage);
             
            uint256 loserFinalGenReward = loserGenReward - riskDeductionFromLoser;

            uint256 winnerAreenaReward = calculateRewardInAreena(winnertokenAmount, totalMinutes);
 
            uint256 sendWinnerGenReward =  winnerGenReward + riskDeductionFromLoser + winnertokenAmount;
            uint256 sendLoserGenReward =  losertokenAmount + loserFinalGenReward;
            
            areenaInCirculation += winnerAreenaReward;
            battle.endingTime = block.timestamp;
            battle.battleTime = totalMinutes;
            battle.completed = true;
            battle.active = false;

            players[battle.winner].winingBattles++;
            players[battle.winner].genAmountPlusBonus += sendWinnerGenReward;
            players[battle.winner].totalArenaTokens += winnerAreenaReward;
            players[battle.loser].losingBattles++;
            players[battle.loser].genAmountPlusBonus += sendLoserGenReward;
            players[battle.winner].totalGenBonus += (winnerGenReward + riskDeductionFromLoser);
            players[battle.loser].totalGenBonus += loserFinalGenReward;
            
            players[battle.winner].battleRecord[stakeCount[battleId][battle.winner]].genBonus = (winnerGenReward + riskDeductionFromLoser);
            players[battle.winner].battleRecord[stakeCount[battleId][battle.winner]].areenaBonus = winnerAreenaReward;
            players[battle.loser].battleRecord[stakeCount[battleId][battle.loser]].genBonus = loserFinalGenReward;
            
            if(battle.creator != battle.joiner){
                players[battle.winner].activeBattles--;
            }
            
            players[battle.loser].activeBattles--;

           emit winnerDetails(winnertokenAmount, (winnerGenReward + riskDeductionFromLoser), winnerAreenaReward);
           emit loserDetails(losertokenAmount,loserFinalGenReward);

        }
    }

    function GenWithdraw(uint256 _percentage) external {

        Player storage player = players[msg.sender];
        
        require(player.genAmountPlusBonus > 0, "You do not have sufficent amount of tokens to withdraw.");

        if(_percentage == 3){
            
            require(genLastTransaction[msg.sender] < block.timestamp,"You canot withdraw amount before 3 minutes");
            genLastTransaction[msg.sender] = block.timestamp + 3 minutes; //hours/////////////////////////

            uint256 sendgenReward = calculateWithdrawThreePercentage(player.genAmountPlusBonus);

            genToken.transfer(msg.sender,sendgenReward);
            player.genAmountPlusBonus -= sendgenReward;
        }
        else if(_percentage == 5){
            
            require(genLastTransaction[msg.sender] < block.timestamp,"You canot withdraw amount before 5 minutes");
            genLastTransaction[msg.sender] = block.timestamp + 5 minutes; //hours//////////////////////

            uint256 sendgenReward = calculateWithdrawFivePercentage(player.genAmountPlusBonus);

            genToken.transfer(msg.sender,sendgenReward);
            player.genAmountPlusBonus -= sendgenReward;
        }
        else if(_percentage == 7){

            require(genLastTransaction[msg.sender] < block.timestamp,"You canot withdraw amount before 7 minutes");
            genLastTransaction[msg.sender] = block.timestamp + 7 minutes; //hours/////////////////

            uint256 sendgenReward = calculateWithdrawSevenPercentage(player.genAmountPlusBonus);

            genToken.transfer(msg.sender,sendgenReward);
            player.genAmountPlusBonus -= sendgenReward;
        }
        else{

            require(_percentage == 3 || _percentage == 5 || _percentage == 7, "Enter the right amount of percentage.");
        }
    }


    function BuyAreenaBoster() external {

        Player storage player = players[msg.sender];

        if(player.walletLimit == 0){
            player.walletLimit = 10*1e18;
        }
        
        require(busdToken.balanceOf(msg.sender) >= areenaBosterPrice, "You didnt have enough amount of USD to buy Areena Boster.");
        busdToken.transferFrom(msg.sender, busdWallet, areenaBosterPrice);

        player.walletLimit += 25*1e18;
    }

    bool private onceGreater;
    
    function sell(uint256 amount) external {
        
        amount = amount.mul(1e18);

         Player storage player = players[msg.sender];

        if(player.walletLimit == 0){
            player.walletLimit = 10*1e18;
        }

        uint256 _walletLimit = player.walletLimit;

        require(amount < _walletLimit,"Please Buy Areena Boster To get All of your reward.");
        require(amount <= (3*1e18), "You can sell only three areena Token per day.");
        require(owner != address(0), "ERC20: approve from the zero address");
        require(msg.sender != address(0), "ERC20: approve to the zero address");
        require(players[msg.sender].totalArenaTokens >= amount, "You do not have sufficient amount of balance.");
        
        if(!onceGreater){
            require(busdToken.balanceOf(busdWallet) >= (102000*1e18) ,"Selling of Areena token will start when areena wallet reaches 102000.");
            onceGreater = true;
        }
        
        uint256 lowerMileStone = 101000*1e18;
        uint256 uppermileStone = 102999*1e18;
        uint256 lowerSetMileStone = 999*1e18;
        uint256 upperSetMileStone = 1000*1e18;
        
        require(busdToken.balanceOf(busdWallet) > lowerMileStone,"lowerMileStone");
        require(busdToken.balanceOf(busdWallet) <= uppermileStone,"uppermileStone");

        if(busdToken.balanceOf(busdWallet) > lowerMileStone && busdToken.balanceOf(busdWallet) <= uppermileStone){

            if(busdToken.balanceOf(busdWallet) > (200000*1e18)){

                require(block.timestamp > areenaLastTransaction[msg.sender],"You canot sell areena token again before 24 hours.");
                
                uint256 sendAmount = amount.mul(afterPrice);
                busdToken.transferFrom(busdWallet,msg.sender, sendAmount);   

                areenaInCirculation -= sendAmount;
                players[msg.sender].totalArenaTokens -= sendAmount;
                
                areenaLastTransaction[msg.sender] = block.timestamp + 4 minutes;//////////hours////////////////

            }
            else{

                require(block.timestamp > areenaLastTransaction[msg.sender],"You canot sell areena token again before 24 hours");

                uint256 sendAmount = amount.mul(initialPrice);
                busdToken.transferFrom(busdWallet,msg.sender, sendAmount);   

                areenaInCirculation -= sendAmount;
                players[msg.sender].totalArenaTokens -= sendAmount;
                
                areenaLastTransaction[msg.sender] = block.timestamp + 4 minutes;//////////////////////hours//////////////
            }
            
        }

        uint256 walletSize = busdToken.balanceOf(busdWallet);

        if(walletSize >= uppermileStone){
            lowerMileStone = uppermileStone.sub(lowerSetMileStone);
            uppermileStone = uppermileStone.add(upperSetMileStone);
        }

    }

    function setAreenaBosterPrice() public view returns(uint256){

        uint256 ABV = totalAreena - areenaInCirculation;
        uint256 findValue = (ABV.div(10000)). mul(25);
        uint256 priceOfBoster = bosterPercentage(findValue);
        
        return priceOfBoster;
	}

    function bosterPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 2000; // 20 % 
        return _amount.mul(_initialPercentage).div(10000);
    }


    function calculateReferalPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 500; // 5 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateWithdrawThreePercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 300; // 3 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateWithdrawFivePercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 500; // 5 %
        return _amount.mul(_initialPercentage).div(10000);
    }
    
    function calculateWithdrawSevenPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 700; // 7 %
        return _amount.mul(_initialPercentage).div(10000);
    }
    
    function calculateRewardInGen(uint256 _amount, uint256 _totalMinutes) public view returns(uint256){
 
        uint256 _initialPercentage = genRewardPercentage;
        
        console.log("_initialPercentage direct",_initialPercentage);
        
        _initialPercentage = (_initialPercentage * _totalMinutes).div(genRewardMultiplicationValue);
        
        console.log("_initialPercentage",_initialPercentage);
        console.log("genRewardMultiplicationValue",genRewardMultiplicationValue);
        
        uint256 value =  ((_amount.mul(_initialPercentage)).div(100 * genRewardMultiplicationValue));
        return value;
    }
    
    function calculateTotalMinutes(uint256 _endingTime, uint256 _startingTime) public pure returns(uint256 _totalMinutes){

        _totalMinutes = ((_endingTime - _startingTime) / 60); // in minutes!
        return _totalMinutes;
    } 

    function calculateJoinerPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 3000; // 30 %
        return _amount.mul(_initialPercentage).div(10000);
    }
    
    
    function calculateCreatorPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 2000; // 20 % 
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateRiskPercentage(uint256 _amount, uint256 _riskPercentage ) public pure returns(uint256){

        uint256 _initialPercentage =_riskPercentage.mul(100) ;
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateSendBackPercentage(uint256 _amount) public pure returns(uint256){

        uint256 _initialPercentage = 200; // 2 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateRewardInAreena (uint256 _amount, uint256 _battleLength) public view  returns(uint256){

        uint256 realAreena = totalAreena - areenaInCirculation;
    
        if( realAreena <= 10000 || realAreena >= 9000){
            return (((1 *_amount).div(525600)).mul(_battleLength));  
        }

        else if( realAreena <= 8999 || realAreena >= 8000){
            return (((9 *_amount).div(525600)).mul(_battleLength)).div(10);  
        }

        else if( realAreena <= 7999 || realAreena >= 7000){
            return (((8 *_amount).div(525600)).mul(_battleLength)).div(10);  
        }

        else if( realAreena >= 6999 || realAreena >= 6000){
            return (((7 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 5999 || realAreena >= 5000){
            return (((6 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 4999 || realAreena >= 4000){
            return (((5 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 3999 || realAreena >= 3000){
            return (((4 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 2999 || realAreena >= 2000){
           return (((3 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 1999 || realAreena >= 1000){
           return (((2 *_amount).div(525600)).mul(_battleLength)).div(10);
        }

        else if( realAreena <= 999 || realAreena >= 1){
           return (((1 *_amount).div(525600)).mul(_battleLength)).div(10);
        }
        else{
            return 0;
        } 
    }

    function playerStakeDetails(address _playerAddress,uint battleCount) public view returns(Stake memory){
        
        Player storage player = players[_playerAddress];
        return player.battleRecord[battleCount];
    }

    function setGenRewardPercentage(uint256 _percentage, uint256 value) external  onlyOwner {
        genRewardMultiplicationValue = value;
        genRewardPercentage = _percentage.mul(value);
    }

    function getAreenaPrice() external view returns(uint256){

        if(busdToken.balanceOf(busdWallet) > (200000*1e18)){
            return afterPrice;
        }
        else{
            return initialPrice;
        }

    }

    function setAreenaInitialPrice(uint256 price) external {
        initialPrice = price;
    }

    function setAreenaAfterPrice(uint256 price) external {
        afterPrice = price;
    }

    function setTreasuryWallet(address _walletAddress) external onlyOwner {
        treasuryWallet = _walletAddress;
    }
    
    function setAreenaWallet(address _walletAddress) external onlyOwner {
        areenaWallet = _walletAddress;
    }

    function setBusdWallet(address _walletAddress) external onlyOwner {
        busdWallet = _walletAddress;
    }

    function getGenRewardPercentage() external view returns(uint256) {
        uint256 genReward = genRewardPercentage.div(genRewardMultiplicationValue);
        return genReward;
    }

    function plateformeEarning () public view returns(uint256){
        return genToken.balanceOf(treasuryWallet);
    }

    function AreenaInTreasury() external view returns(uint256){
        
        uint256 realAreena = totalAreena - areenaInCirculation;
        return realAreena;
    }

    function GenInTreasury() external view returns(uint256){
        return genToken.balanceOf(treasuryWallet);
    }
     
    function BusdInTreasury() external view returns(uint256){
        return busdToken.balanceOf(busdWallet);
    }

    function getAreenaBosterPrice() external view returns(uint256){  
        return setAreenaBosterPrice();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    
}
