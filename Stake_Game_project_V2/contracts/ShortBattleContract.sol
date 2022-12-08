// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IBEP20 {
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

interface StakingContract {

    function players(address _playerAddress) external view returns(uint256 walletLimit, uint256 totalArenaTokens,
            uint256 genAmountPlusBonus, uint256 battleCount, uint256 withdrawTime, uint256 activeBattles, 
            uint256 winingBattles, uint256 losingBattles, uint256 totalGenBonus, uint256 referalAmount, 
            uint256 totalAmountStaked);
    function plateformeEarning() external view returns (uint256);
    function riskOptions() external view returns(uint256[5] memory);
    function treasuryWallet() external view returns(address);
    function updatePalyerGenAmountPlusBonus(address _playerAddress,uint256 _genAmount) external;
    
}

interface StakingHelpingContract {
    function updatePalyerGenAmountPlusBonus(address _playerAddress,uint256 _genAmount) external;
}


contract ShortBattleContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    
    IBEP20 public genToken;
    StakingContract public stakingContract;
    StakingHelpingContract public stakingHelpingContract;

    struct ShortBattleStake {
        uint256 amount;
        uint256 genBonus;
    }

    struct Player {
        uint256 tieBattles;
        uint256 battleCount;
        uint256 winingBattles;
        uint256 losingBattles;
        uint256 referalAmount;
        uint256 totalAmountStaked;
        uint256 loanAmount;
        uint256[] creatorBattleIds;
    }

    struct ShortBattle {
        bool tie;
        bool joined;
        bool leaved;
        bool completed;
        address loser;
        address winner;
        address joiner;
        address creator;
        uint256 stakeAmount;
        uint256 riskPercentage;
        uint256 winningAmount;
        uint256 losingAmount;
        Choice  creatorChoice;
        Choice  joinerChoice;
    }

    struct referenceInfo {
        uint256 creatorReferalAmount1;
        uint256 creatorReferalAmount2;
        uint256 creatorReferalAmount3;
        uint256 joinerReferalAmount1;
        uint256 joinerReferalAmount2;
        uint256 joinerReferalAmount3;
        address battleCreator;
        address battleJoiner;
        address creatorReferalPerson1;
        address creatorReferalPerson2;
        address creatorReferalPerson3;
        address joinerReferalPerson1;
        address joinerReferalPerson2;
        address joinerReferalPerson3;
    }

    enum Choice {
        f302f0ea1db5df02bef4e6520435b493640eff8cf840ac709d6b5e5f746b3f76, 
        c87f290656e4b4d73c43dcbe6e37a6405fbe06ec3910c3ae3c9e10e8e9dbd12a, 
        dfcadfa75587556dcd477edb9800b7cdefa3976f9de5bc3c9f83fc71198f905e}
    

    bool public stopBattles;
    
    uint256 public shortBattleId;
    uint256[3] public riskOptions;
    uint256 private loserFinalGenReward;        
    uint256 private winnerGenReward;

    address public mainStakingContractAddress;
    
    mapping(address => Player) public players;
    mapping(uint256 => ShortBattle) public battles;
    mapping(uint256 => referenceInfo) public referalPerson;
    // mapping(address => uint256[]) public joinerBattleIds;
    mapping(uint256 => mapping(address => uint256)) public stakeCount;
    mapping(address => mapping(uint256 => ShortBattleStake)) public battleRecord;



    event createShortBattle(address indexed battleCreator, uint256 stakeAmount, uint256 indexed battleId);
    event winningInfo(address battleWinner, uint256 winningAmount, address battleLoser, 
            uint256 loserAmount, Choice creatorChoice, Choice joinerChoice);
    event leaveBattle(address battleCreator, uint256 battleId, uint256 stakedAmount);
    event battleTied(address battleCreator, uint256 creatorAmount, address battleJoiner,
            uint256 joinerAmount, Choice creatorChoice, Choice joinerChoice);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _genToken, address _stakingContract, address _stakingHelpingContract) initializer public {

        genToken = IBEP20(_genToken);
        stakingContract = StakingContract(_stakingContract);
        stakingHelpingContract = StakingHelpingContract(_stakingHelpingContract);
        mainStakingContractAddress = _stakingContract;

        riskOptions = [25, 50, 75];

        
        __Ownable_init();
        __UUPSUpgradeable_init();
    }
    //=========================== Create Short Battle ===================
    
    function CreateBattle( uint256 _amount, uint256 _riskPercentage, address _referalPerson1,
                    address _referalPerson2, address _referalPerson3, Choice _creatorChoice) external {

        require(!stopBattles,"Battles are stoped by the owner.");

        ShortBattle storage battle = battles[shortBattleId];
        battle.creator = msg.sender;

        uint256 stakeAmount = _amount.mul(1e18);

        uint256 fivePercentAmount = calculateDeductedPercentage(stakeAmount);

        require(_referalPerson1 != address(0) && _referalPerson1 != msg.sender &&
                _referalPerson2 != address(0) && _referalPerson2 != msg.sender &&
                _referalPerson3 != address(0) && _referalPerson3 != msg.sender,
            "Either _referalPerson is a zero address or battle creator person could not be a referalPerson it self.");


        require(stakeAmount >= 1*1e18 && stakeAmount <= (1000*1e18), 
            "You can between 1 Gen token to 1000 Gen tokens to enter into the battle.");

        require(_riskPercentage == riskOptions[0] || _riskPercentage == riskOptions[1] || _riskPercentage == riskOptions[2],
            "Please chose the valid risk percentage.");


        (,,uint256 genAmountPlusBonus,,,,,,,,) = stakingContract.players(battle.creator);
        
        uint256 _loanAmount = players[msg.sender].loanAmount;

        require((genToken.balanceOf(battle.creator).add(genAmountPlusBonus))  >= _loanAmount, 
            "You does not have sufficent amount of gen token to start a battle.");
        
        require(((genToken.balanceOf(battle.creator).add(genAmountPlusBonus)).sub(_loanAmount)) >= stakeAmount, 
            "You does not have sufficent amount of gen token to start a battle.");
        
        referalPerson[shortBattleId].battleCreator = battle.creator;
        referalPerson[shortBattleId].creatorReferalPerson1 = _referalPerson1;
        referalPerson[shortBattleId].creatorReferalPerson2 = _referalPerson2;
        referalPerson[shortBattleId].creatorReferalPerson3 = _referalPerson3;
        
        players[msg.sender].creatorBattleIds.push(shortBattleId);

        battle.stakeAmount = stakeAmount;
        battle.creatorChoice = _creatorChoice;
        battle.riskPercentage = _riskPercentage;


        if (genToken.balanceOf(battle.creator) < stakeAmount) {

            uint256 amountFromUser = genToken.balanceOf(battle.creator);
            uint256 amountFromAddress = stakeAmount.sub(amountFromUser);

            if(amountFromUser == 0){
                
                players[msg.sender].loanAmount += amountFromAddress; 
                
                require(
                    genToken.transferFrom(stakingContract.treasuryWallet(), address(this), fivePercentAmount),
                    "Token didnt transfer."
                );

            }
            else if (amountFromUser > fivePercentAmount){

                players[msg.sender].loanAmount += amountFromAddress;
                uint256 remainingAmount = amountFromUser.sub(fivePercentAmount);

                require(
                    genToken.transferFrom(battle.creator, address(this), fivePercentAmount),
                    "Token didnt transfer."
                );

                require(
                    genToken.transferFrom(battle.creator, mainStakingContractAddress, remainingAmount),
                    "Token didnt transfer."
                );

            }
            
            else {

                players[msg.sender].loanAmount += amountFromAddress; 
                uint256 remainingAmount = fivePercentAmount.sub(amountFromUser);
               
                require(
                    genToken.transferFrom(battle.creator, address(this), amountFromUser),
                    "Token didnt transfer."
                );

                require(
                    genToken.transferFrom(stakingContract.treasuryWallet(), address(this), remainingAmount),
                    "Token didnt transfer."
                );


            }
           

        } else {

            uint256 leftAmount = stakeAmount.sub(fivePercentAmount);
             
             require(
                    genToken.transferFrom(battle.creator, address(this), fivePercentAmount),
                    "Token didnt transfer."
                );

                require(
                    genToken.transferFrom(battle.creator, mainStakingContractAddress, leftAmount),
                    "Token didnt transfer."
                );
        }

        emit createShortBattle(battle.creator, stakeAmount, shortBattleId);
        shortBattleId++;

    }


    //============================ Join Short battle ==========================

     function JoinBattle(uint256 _amount, uint256 _battleId, address _joinerReferalPerson1,
                        address _joinerReferalPerson2, address _joinerReferalPerson3,
                        Choice _joinerChoice) external {

        require(!stopBattles,"Battles are stoped by the owner.");
        
        ShortBattle storage battle = battles[_battleId];
        Player storage player = players[msg.sender];
        battle.joiner = msg.sender;

        uint256 stakeAmount = _amount.mul(1e18);


        uint256 deductedAmount = calculateDeductedPercentage(stakeAmount);
        

        require(_joinerReferalPerson1 != address(0) && _joinerReferalPerson1 != msg.sender &&
                _joinerReferalPerson2 != address(0) && _joinerReferalPerson2 != msg.sender &&
                _joinerReferalPerson3 != address(0) && _joinerReferalPerson3 != msg.sender,
                "Either _joinerReferalPerson is a zero address or battle joiner person couldent be a referalPerson it self");

        require(battle.joiner != battle.creator, 
            "You cannot join your own battle.");

        require(!battle.leaved && !battle.completed && battle.stakeAmount != 0,
                "You can not join this battle. This battle in not created yet or may b already joined.");

        require(stakeAmount == battle.stakeAmount,
            "Enter the exact amount of tokens to be a part of this battle.");

        (,,uint256 joinerGenAmountPlusBonus,,,,,,,,) = stakingContract.players(battle.joiner);
        uint256 _loanAmount = players[msg.sender].loanAmount;

        require((genToken.balanceOf(battle.joiner).add(joinerGenAmountPlusBonus))  >= _loanAmount, 
            "You does not have sufficent amount of gen token to start a battle.");

        require(((genToken.balanceOf(battle.joiner).add(joinerGenAmountPlusBonus)).sub(_loanAmount)) >= stakeAmount,
            "You does not have sufficent amount of gen token to join battle.");
        

        players[battle.creator].battleCount++;
        player.battleCount++;

        battle.joined = true;


    // joinerBattleIds[battle.joiner].push(_battleId);

    
        if (genToken.balanceOf(msg.sender) < stakeAmount) {

            uint256 amountFromUser = genToken.balanceOf(battle.creator);
            uint256 amountFromAddress = stakeAmount.sub(amountFromUser);

            if(amountFromUser == 0){
                
                players[msg.sender].loanAmount += amountFromAddress; 
                
                require(
                    genToken.transferFrom(stakingContract.treasuryWallet(), address(this), deductedAmount),
                    "Token didnt transfer."
                );

            }
            else if (amountFromUser > deductedAmount){

                players[msg.sender].loanAmount += amountFromAddress;
                uint256 remainingAmount = amountFromUser.sub(deductedAmount);

                require(
                    genToken.transferFrom(battle.joiner, address(this), deductedAmount),
                    "Token didnt transfer."
                );

                require(
                    genToken.transferFrom(battle.joiner, mainStakingContractAddress, remainingAmount),
                    "Token didnt transfer."
                );

            }
            
            else {

                players[msg.sender].loanAmount += amountFromAddress; 
                uint256 remainingAmount = deductedAmount.sub(amountFromUser);
               
                require(
                    genToken.transferFrom(battle.joiner, address(this), amountFromUser),
                    "Token didnt transfer."
                );

                require(
                    genToken.transferFrom(stakingContract.treasuryWallet(), address(this), remainingAmount),
                    "Token didnt transfer."
                );


            }
            
        } 
        else {

            uint256 leftAmount = stakeAmount.sub(deductedAmount);

            require(
                    genToken.transferFrom(battle.joiner, mainStakingContractAddress, leftAmount),
                    "Token didnt transfer."
                );
            
            require(
                    genToken.transferFrom(battle.joiner, address(this), deductedAmount),
                    "Token didnt transfer."
                );
        }



        uint256 afterDeductedAmount = stakeAmount.sub(deductedAmount);

        uint256 riskDeductionFromLoser = calculateRiskPercentage(afterDeductedAmount, battle.riskPercentage);
        loserFinalGenReward = afterDeductedAmount.sub(riskDeductionFromLoser);
            
        winnerGenReward = afterDeductedAmount.add(riskDeductionFromLoser);

        battle.joinerChoice = _joinerChoice;

        
        if (battle.creatorChoice == battle.joinerChoice) {

            players[battle.creator].tieBattles += 1;
            players[battle.joiner].tieBattles += 1;

            if(players[battle.creator].loanAmount > 0){
                
                if(players[battle.creator].loanAmount >= afterDeductedAmount){

                    players[battle.creator].loanAmount -= afterDeductedAmount;
                }else{

                    uint256 sendAmount = afterDeductedAmount.sub(players[battle.creator].loanAmount);
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                    players[battle.creator].loanAmount = 0;
                }
            }
            else{
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,afterDeductedAmount);
            }

            if(players[battle.joiner].loanAmount > 0){
                 
                if(players[battle.joiner].loanAmount >= afterDeductedAmount){

                    players[battle.joiner].loanAmount -= afterDeductedAmount;
                }else{

                    uint256 sendAmount = afterDeductedAmount.sub(players[battle.joiner].loanAmount);
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                    players[battle.joiner].loanAmount = 0;
                }
            }
            else{

                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,afterDeductedAmount);
            }

            battle.tie = true;
            
            
        } 
        else if (battle.creatorChoice == Choice.f302f0ea1db5df02bef4e6520435b493640eff8cf840ac709d6b5e5f746b3f76) {
            if (battle.joinerChoice == Choice.c87f290656e4b4d73c43dcbe6e37a6405fbe06ec3910c3ae3c9e10e8e9dbd12a) {

                if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= loserFinalGenReward){

                        players[battle.creator].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= winnerGenReward){

                        players[battle.joiner].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }
                
                battle.winner = battle.joiner;
                battle.loser = battle.creator;


            } else {

                 if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= winnerGenReward){

                        players[battle.creator].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= loserFinalGenReward){

                        players[battle.joiner].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,loserFinalGenReward);
                }

                battle.winner = battle.creator;
                battle.loser = battle.joiner;
            
            }

        } else if (battle.creatorChoice == Choice.c87f290656e4b4d73c43dcbe6e37a6405fbe06ec3910c3ae3c9e10e8e9dbd12a) {
            if (battle.joinerChoice == Choice.dfcadfa75587556dcd477edb9800b7cdefa3976f9de5bc3c9f83fc71198f905e) {

                 if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= loserFinalGenReward){

                        players[battle.creator].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= winnerGenReward){

                        players[battle.joiner].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }

                battle.winner = battle.joiner;
                battle.loser = battle.creator;

            } else {

                if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= winnerGenReward){

                        players[battle.creator].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= loserFinalGenReward){

                        players[battle.joiner].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,loserFinalGenReward);
                }

                battle.winner = battle.creator;
                battle.loser = battle.joiner;

            }

        } else if (battle.creatorChoice == Choice.dfcadfa75587556dcd477edb9800b7cdefa3976f9de5bc3c9f83fc71198f905e) {
            if (battle.joinerChoice == Choice.f302f0ea1db5df02bef4e6520435b493640eff8cf840ac709d6b5e5f746b3f76) {

                if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= loserFinalGenReward){

                        players[battle.creator].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= winnerGenReward){

                        players[battle.joiner].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }

                battle.winner = battle.joiner;
                battle.loser = battle.creator;


            } else {

                 if(players[battle.creator].loanAmount > 0){
                
                    if(players[battle.creator].loanAmount >= winnerGenReward){

                        players[battle.creator].loanAmount -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward.sub(players[battle.creator].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        players[battle.creator].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(players[battle.joiner].loanAmount > 0){
                    if(players[battle.joiner].loanAmount >= loserFinalGenReward){

                        players[battle.joiner].loanAmount -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward.sub(players[battle.joiner].loanAmount);
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        players[battle.joiner].loanAmount = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,loserFinalGenReward);
                }

                battle.winner = battle.creator;
                battle.loser = battle.joiner;

            }
        }

        StoreInfo(battle.creator, battle.joiner, _battleId, afterDeductedAmount, battle.winner, battle.loser);

        AllReferalInfo(stakeAmount, _battleId, _joinerReferalPerson1, _joinerReferalPerson2,_joinerReferalPerson3, msg.sender);
        sendTreasury( battle.creator, battle.joiner,stakeAmount);

        if(battle.tie){
            emit battleTied(
                battle.creator,
                afterDeductedAmount,
                battle.joiner,
                afterDeductedAmount,
                battle.creatorChoice,
                battle.joinerChoice
            );   
        }else{
            emit winningInfo(
                battle.winner,
                riskDeductionFromLoser, 
                battle.loser, 
                loserFinalGenReward,
                battle.creatorChoice,
                battle.joinerChoice
            );
        }

    }


    function StoreInfo(address _creator, address _joiner, uint256 _battleId, uint256 _afterDeductedAmount,
                    address _winner, address _loser) private {

        players[_joiner].totalAmountStaked += _afterDeductedAmount;
        players[_creator].totalAmountStaked += _afterDeductedAmount;
        battleRecord[_creator][stakeCount[_battleId][_creator]].amount = _afterDeductedAmount;
        battleRecord[_joiner][stakeCount[_battleId][_joiner]].amount = _afterDeductedAmount;
       
        battleRecord[_winner][stakeCount[_battleId][_winner]].genBonus = winnerGenReward;
        battleRecord[_loser][stakeCount[_battleId][_loser]].genBonus = loserFinalGenReward;

        battles[_battleId].completed = true;
        players[battles[_battleId].winner].winingBattles++;
        players[battles[_battleId].loser].losingBattles++;
        battles[_battleId].winningAmount = winnerGenReward;
        battles[_battleId].losingAmount = loserFinalGenReward;

        stakeCount[_battleId][_creator] = players[_creator].battleCount;
        stakeCount[_battleId][_joiner] = players[_joiner].battleCount;
    } 
    
    function calculateRiskPercentage(uint256 _amount, uint256 _riskPercentage) private pure returns (uint256){

        uint256 _initialPercentage = _riskPercentage.mul(100);
        return _amount.mul(_initialPercentage).div(10000);
    }


    function sendTreasury(address _creator, address _joiner,uint256 _stakeAmount) private {

            (,,,,,,,,,,uint256 creatorTotalAmountStaked) = stakingContract.players(_creator);
            (,,,,,,,,,,uint256 joinerTotalAmountStaked) = stakingContract.players(_joiner);
            
            if(creatorTotalAmountStaked >= _stakeAmount){
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(_creator,calculateTreasuryPercentage(_stakeAmount));
            }else{
                 require(
                    genToken.transfer(stakingContract.treasuryWallet(), calculateTreasuryPercentage(_stakeAmount)),
                    "tokens didnt transfer"
                );
            }

            if(joinerTotalAmountStaked >= _stakeAmount){
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(_joiner,calculateTreasuryPercentage(_stakeAmount));
            }else{
                require(
                    genToken.transfer(stakingContract.treasuryWallet(), calculateTreasuryPercentage(_stakeAmount)),
                    "tokens didnt transfer"
                );
            }

        }

    

    function AllReferalInfo(uint256 _stakeAmount,uint256 _battleId, address _joinerReferalPerson1,
                        address _joinerReferalPerson2, address _joinerReferalPerson3, address _battleJoiner) private {

         ////////// Joiner_Referal_section /////////////

         uint256 referalAmount = calculateReferalPercentage(_stakeAmount);

        referalPerson[_battleId].battleJoiner = _battleJoiner;
        referalPerson[_battleId].joinerReferalPerson1 = _joinerReferalPerson1;
        referalPerson[_battleId].joinerReferalPerson2 = _joinerReferalPerson2;
        referalPerson[_battleId].joinerReferalPerson3 = _joinerReferalPerson3;
        
        referalPerson[_battleId].joinerReferalAmount1 = referalAmount;
        referalPerson[_battleId].joinerReferalAmount2 = referalAmount;
        referalPerson[_battleId].joinerReferalAmount3 = referalAmount;


        ////////// Creator_Referal_section /////////////

        referalPerson[_battleId].creatorReferalAmount1 = referalAmount;
        referalPerson[_battleId].creatorReferalAmount2 = referalAmount;
        referalPerson[_battleId].creatorReferalAmount3 = referalAmount;
        

        stakingHelpingContract.updatePalyerGenAmountPlusBonus(_joinerReferalPerson1,referalAmount);
        stakingHelpingContract.updatePalyerGenAmountPlusBonus(referalPerson[_battleId].creatorReferalPerson1,referalAmount);

        require(
            genToken.transfer(_joinerReferalPerson2,referalAmount),
            "tokens didnt transfer"
        );
        require(
            genToken.transfer(_joinerReferalPerson3,referalAmount),
            "tokens didnt transfer"
        );

        require(
            genToken.transfer(referalPerson[_battleId].creatorReferalPerson2,referalAmount),
            "tokens didnt transfer"
        );
        require(
            genToken.transfer(referalPerson[_battleId].creatorReferalPerson3,referalAmount),
            "tokens didnt transfer"
        );


    }

    function calculateDeductedPercentage(uint256 _amount) private pure returns (uint256){

        uint256 _initialPercentage = 500; // 5 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateReferalPercentage(uint256 _amount) private pure returns (uint256){

        uint256 _initialPercentage = 100; // 1 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateTreasuryPercentage(uint256 _amount) private pure returns (uint256){

        uint256 _initialPercentage = 200; // 2 %
        return _amount.mul(_initialPercentage).div(10000);
    }
     
    
/////////////////////////////////////////////////////////////////////////////////////

       function LeaveBattle(uint256 _battleId) public {
        
        ShortBattle storage battle = battles[_battleId];

        require(msg.sender == battle.creator,
            "You must be a part of a battle before leaving it.");
        require(!battle.leaved && !battle.joined && !battle.completed," battle creator Already leave the battle.");

        if(players[battle.creator].loanAmount > 0){

            if(players[battle.creator].loanAmount >= battle.stakeAmount){

                players[battle.creator].loanAmount -= battle.stakeAmount;
            }
            else{

                uint256 sendAmount = battle.stakeAmount.sub(players[battle.creator].loanAmount);
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                players[battle.creator].loanAmount = 0;
            }
        }
        else{
            stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,battle.stakeAmount);
        }
        battle.leaved = true;

        emit leaveBattle(battle.creator,_battleId,battle.stakeAmount);
    }

    function getAllCreatorBattleIds(address _playerAddress) external view returns (uint256[] memory){
        return players[_playerAddress].creatorBattleIds;
    }
    
    // function getAllJoinerBattleIds(address _playerAddress) external view returns (uint256[] memory){
    //     return joinerBattleIds[_playerAddress];
    // }
 // ================ Contract Info ==========

    function withdrawContractBalance(uint256 _amount) external onlyOwner {

        require(genToken.transfer(msg.sender, _amount),"token did not transfer");  
    }
    
    function getContractBalance() public view onlyOwner returns (uint256) {
        return genToken.balanceOf(address(this));
    }

    function stopTheBattles(bool _stopThem) public onlyOwner {
        stopBattles = _stopThem;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

}
