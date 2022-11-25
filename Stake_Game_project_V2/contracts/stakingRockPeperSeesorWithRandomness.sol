// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


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
    function treasuryWallet() external view returns(address);
    function updatePalyerGenAmountPlusBonus(address _playerAddress,uint256 _genAmount) external;
    
}

interface StakingHelpingContract {
    function updatePalyerGenAmountPlusBonus(address _playerAddress,uint256 _genAmount) external;
}


contract ShortBattleContract is Ownable {

    using SafeMath for uint256;
    
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
        uint256 totalAmountStaked;
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

    enum Choice {Rock, Paper, Scissor}
    uint256[3] public riskOptions = [25, 50, 75];
    
    uint256 shortBattleId;
    bool public stopBattles;

    mapping(address => Player) public players;
    mapping(uint256 => ShortBattle) public battles;
    mapping(uint256 => referenceInfo) public referalPerson;
    mapping(address => uint256[]) public creatorBattleIds;
    mapping(address => uint256[]) public joinerBattleIds;
    mapping(uint256 => mapping(address => uint256)) public stakeCount;
    mapping(address => mapping(uint256 => ShortBattleStake)) public battleRecord;
    mapping(address => uint256) public loanAmount;


    event createShortBattle(address indexed battleCreator, uint256 stakeAmount, uint256 indexed battleId);
    event winningInfo(address battleWinner, uint256 winningAmount, address battleLoser, uint256 losingAmount, Choice joinerChoice);
    event leaveBattle(address battleCreator, uint256 battleId, uint256 stakedAmount);
    
    constructor(address _genToken, address _stakingContract, address _stakingHelpingContract){
        
        genToken = IBEP20(_genToken);
        stakingContract = StakingContract(_stakingContract);
        stakingHelpingContract = StakingHelpingContract(_stakingHelpingContract);

    }
    //=========================== Create Short Battle ===================
    
    function CreateBattle( uint256 _amount, uint256 _riskPercentage, address _referalPerson1,
                    address _referalPerson2, address _referalPerson3, Choice _creatorChoice) external {

        ShortBattle storage battle = battles[shortBattleId];
        battle.creator = msg.sender;

        require(!stopBattles,"Battles are stoped by the owner.");

        uint256 stakeAmount = _amount.mul(1e18);

        require(_referalPerson1 != address(0) && _referalPerson2 != address(0) 
            && _referalPerson3 != address(0) && _referalPerson1 != msg.sender,
            "Either _referalPerson is a zero address or battle creator person could not be a referalPerson it self.");

        require(stakeAmount >= 1*1e18, 
            "You must stake atleast 1 Gen tokens to enter into the battle.");
        require(stakeAmount <= (1000*1e18), 
            "You can not stake more then 1000 Gen tokens to create a battle.");
        
        require(_riskPercentage == riskOptions[0] || _riskPercentage == riskOptions[1] || _riskPercentage == riskOptions[2],
            "Please chose the valid risk percentage.");
        
        (,,uint256 genAmountPlusBonus,,,,,,,,) = stakingContract.players(battle.creator);
        uint256 _loanAmount = loanAmount[msg.sender];
        
        require(((genToken.balanceOf(battle.creator) + genAmountPlusBonus) - _loanAmount) >= stakeAmount, 
            "You does not have sufficent amount of gen token to start a battle.");
        

        if (genToken.balanceOf(battle.creator) < stakeAmount) {
            
            uint256 amountFromUser = genToken.balanceOf(battle.creator);
            
            genToken.transferFrom(battle.creator, address(this), amountFromUser);

            uint256 amountFromAddress = stakeAmount - amountFromUser;
            loanAmount[msg.sender] += amountFromAddress; 

        } else {
            genToken.transferFrom(battle.creator, address(this), stakeAmount);
        }

        emit createShortBattle(battle.creator, stakeAmount, shortBattleId);

        referalPerson[shortBattleId].battleCreator = battle.creator;
        referalPerson[shortBattleId].creatorReferalPerson1 = _referalPerson1;
        referalPerson[shortBattleId].creatorReferalPerson2 = _referalPerson2;
        referalPerson[shortBattleId].creatorReferalPerson3 = _referalPerson3;
        
        creatorBattleIds[battle.creator].push(shortBattleId);

        shortBattleId++;
        battle.creatorChoice = _creatorChoice;
        battle.stakeAmount = stakeAmount;
        battle.riskPercentage = _riskPercentage;
    }

    uint256 deductedAmount;
    uint256 afterDeductedAmount;
    uint256 riskDeductionFromLoser ;
    uint256 loserFinalGenReward;   
    uint256 winnerGenReward;
    uint256 choice;



    //============================ Join Short battle ==========================

     function JoinBattle(uint256 _amount, uint256 _battleId, address _joinerReferalPerson1,
                        address _joinerReferalPerson2, address _joinerReferalPerson3) external {
        
        ShortBattle storage battle = battles[_battleId];
        Player storage player = players[msg.sender];
        battle.joiner = msg.sender;

        uint256 stakeAmount = _amount.mul(1e18);

        require(_joinerReferalPerson1 != address(0) && _joinerReferalPerson2 != address(0) &&
                _joinerReferalPerson3 != address(0) && _joinerReferalPerson1 != msg.sender,
                "Either _joinerReferalPerson is a zero address or battle joiner person couldent be a referalPerson it self");

        require(battle.joiner != battle.creator, 
            "You cannot join your own battle.");

        require(!battle.joined && !battle.leaved && battle.stakeAmount != 0,
            "You can not join this battle. This battle in not created yet!.");


        require(stakeAmount == battle.stakeAmount,
            "Enter the exact amount of tokens to be a part of this battle.");

        (,,uint256 joinerGenAmountPlusBonus,,,,,,,,) = stakingContract.players(battle.joiner);
        uint256 _loanAmount = loanAmount[msg.sender];

        require(((genToken.balanceOf(battle.joiner) + joinerGenAmountPlusBonus) - _loanAmount) >= stakeAmount,
            "You does not have sufficent amount of gen token to join battle.");
        

        players[battle.creator].battleCount++;
        player.battleCount++;

        battle.joined = true;

        checkBattleCount(_battleId, battle.creator, battle.joiner);

        joinerBattleIds[battle.joiner].push(_battleId);

        if (genToken.balanceOf(msg.sender) < stakeAmount) {
            
            uint256 amountFromUser = genToken.balanceOf(battle.joiner);
            genToken.transferFrom(battle.joiner, address(this), amountFromUser);

            uint256 amountFromAddress = stakeAmount - amountFromUser;
            loanAmount[msg.sender] += amountFromAddress;
        
        } else {
            genToken.transferFrom(battle.joiner, address(this), stakeAmount);
        }

        AllReferalInfo(stakeAmount, _battleId, _joinerReferalPerson1, _joinerReferalPerson2,_joinerReferalPerson3, msg.sender);
        sendTreasury( battle.creator, battle.joiner,stakeAmount);

        deductedAmount = calculateDeductedPercentage(stakeAmount);
        afterDeductedAmount = stakeAmount - deductedAmount;


        riskDeductionFromLoser = calculateRiskPercentage(afterDeductedAmount, battle.riskPercentage);
        loserFinalGenReward = afterDeductedAmount - riskDeductionFromLoser;
            
        winnerGenReward = afterDeductedAmount + riskDeductionFromLoser;

        choice = numberGenerator();

        battle.joinerChoice = returnChoice(choice);


        
         if (battle.creatorChoice == battle.joinerChoice) {

            players[battle.creator].tieBattles += 1;
            players[battle.joiner].tieBattles += 1;

            if(loanAmount[battle.creator] > 0){
                
                if(loanAmount[battle.creator] >= afterDeductedAmount){

                    loanAmount[battle.creator] -= afterDeductedAmount;
                }else{

                    uint256 sendAmount = afterDeductedAmount - loanAmount[battle.creator];
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                    loanAmount[battle.creator] = 0;
                }
            }
            else{
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,afterDeductedAmount);
            }

            if(loanAmount[battle.joiner] > 0){
                 
                if(loanAmount[battle.joiner] >= afterDeductedAmount){

                    loanAmount[battle.joiner] -= afterDeductedAmount;
                }else{

                    uint256 sendAmount = afterDeductedAmount - loanAmount[battle.joiner];
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                    loanAmount[battle.joiner] = 0;
                }
            }
            else{

                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,afterDeductedAmount);
            }

            battle.tie = true;
            
        } 
        else if (battle.creatorChoice == Choice.Rock) {
            if (battle.joinerChoice == Choice.Paper) {

                // creator: rock, joiner: paper, joiner win
                if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= loserFinalGenReward){

                        loanAmount[battle.creator] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= winnerGenReward){

                        loanAmount[battle.joiner] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }
                
                battle.winner = battle.joiner;
                battle.loser = battle.creator;

            } else {
                // creator: rock, joiner: scissor, creator win

                 if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= winnerGenReward){

                        loanAmount[battle.creator] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= loserFinalGenReward){

                        loanAmount[battle.joiner] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,loserFinalGenReward);
                }

                battle.winner = battle.creator;
                battle.loser = battle.joiner;
            }

        } else if (battle.creatorChoice == Choice.Paper) {
            if (battle.joinerChoice == Choice.Scissor) {

                // creator: paper, joiner: scissor, joiner win
                 if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= loserFinalGenReward){

                        loanAmount[battle.creator] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= winnerGenReward){

                        loanAmount[battle.joiner] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }

                battle.winner = battle.joiner;
                battle.loser = battle.creator;

            } else {

                // creator: paper, joiner: rock, creator win
                if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= winnerGenReward){

                        loanAmount[battle.creator] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= loserFinalGenReward){

                        loanAmount[battle.joiner] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,loserFinalGenReward);
                }

                battle.winner = battle.creator;
                battle.loser = battle.joiner;
            }

        } else if (battle.creatorChoice == Choice.Scissor) {
            if (battle.joinerChoice == Choice.Rock) {

                // creator: scissor, joiner: rock, joiner win
                if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= loserFinalGenReward){

                        loanAmount[battle.creator] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,loserFinalGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= winnerGenReward){

                        loanAmount[battle.joiner] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,winnerGenReward);
                }

                battle.winner = battle.joiner;
                battle.loser = battle.creator;

            } else {
                // creator: scissor, joiner: paper, creator win

                 if(loanAmount[battle.creator] > 0){
                
                    if(loanAmount[battle.creator] >= winnerGenReward){

                        loanAmount[battle.creator] -= winnerGenReward;
                    }else{

                        uint256 sendAmount = winnerGenReward - loanAmount[battle.creator];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                        loanAmount[battle.creator] = 0;
                    }
                }
                else{
                    stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,winnerGenReward);
                }

                if(loanAmount[battle.joiner] > 0){
                    if(loanAmount[battle.joiner] >= loserFinalGenReward){

                        loanAmount[battle.joiner] -= loserFinalGenReward;
                    }else{

                        uint256 sendAmount = loserFinalGenReward - loanAmount[battle.joiner];
                        stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.joiner,sendAmount);
                        loanAmount[battle.joiner] = 0;
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
        battle.completed = true;
        players[battle.winner].winingBattles++;
        players[battle.loser].losingBattles++;

        emit winningInfo(battle.winner, winnerGenReward, battle.loser, loserFinalGenReward, battle.joinerChoice);

    }

    function numberGenerator() internal view returns(uint256){
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            shortBattleId,
            stakingContract.plateformeEarning(),
            block.timestamp,
            block.difficulty,
            msg.sender))).mod(3);
            return randomNumber;
    }

    function returnChoice(uint index) public pure returns(Choice) {
        if(index == 0){

            return Choice.Rock;
        } 
        else if(index == 1){

            return Choice.Paper;
        } 
        else if(index == 2){
           return Choice.Scissor;
        }
        else {
            revert("random choive isnt right");
        }
       
   }

    
    function checkBattleCount(uint256 _battleId, address _creator, address _joiner) private {
        stakeCount[_battleId][_creator] = players[_creator].battleCount;
        stakeCount[_battleId][_joiner] = players[_joiner].battleCount;

    }

    function StoreInfo(address _creator, address _joiner, uint256 _battleId, uint256 _afterDeductedAmount,
                    address _winner, address _loser) private {

        players[_joiner].totalAmountStaked += _afterDeductedAmount;
        players[_creator].totalAmountStaked += _afterDeductedAmount;
        battleRecord[_creator][stakeCount[_battleId][_creator]].amount = _afterDeductedAmount;
        battleRecord[_joiner][stakeCount[_battleId][_joiner]].amount = _afterDeductedAmount;
       
        battleRecord[_winner][stakeCount[_battleId][_winner]].genBonus = (winnerGenReward + riskDeductionFromLoser);
        battleRecord[_loser][stakeCount[_battleId][_loser]].genBonus = loserFinalGenReward;
    } 
    
    function calculateRiskPercentage(uint256 _amount, uint256 _riskPercentage) public pure returns (uint256){

        uint256 _initialPercentage = _riskPercentage.mul(100);
        return _amount.mul(_initialPercentage).div(10000);
    }


    function sendTreasury(address _creator, address _joiner,uint256 _stakeAmount) internal {

            (,,,,,,,,,,uint256 creatorTotalAmountStaked) = stakingContract.players(_creator);
            (,,,,,,,,,,uint256 joinerTotalAmountStaked) = stakingContract.players(_joiner);

            if(creatorTotalAmountStaked >= _stakeAmount){
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(_creator,calculateTreasuryPercentage(_stakeAmount));
            }else{
                genToken.transfer(stakingContract.treasuryWallet(), calculateTreasuryPercentage(_stakeAmount));
            }

            if(joinerTotalAmountStaked >= _stakeAmount){
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(_joiner,calculateTreasuryPercentage(_stakeAmount));
            }else{
                genToken.transfer(stakingContract.treasuryWallet(), calculateTreasuryPercentage(_stakeAmount));
            }

        }

    

    function AllReferalInfo(uint256 _stakeAmount,uint256 _battleId, address _joinerReferalPerson1,
                        address _joinerReferalPerson2, address _joinerReferalPerson3, address _battleJoiner) internal {

         ////////// Joiner_Referal_section /////////////

         uint256 referalAmount = calculateReferalPercentage(_stakeAmount);

        referalPerson[_battleId].battleJoiner = _battleJoiner;
        referalPerson[_battleId].joinerReferalPerson1 = _joinerReferalPerson1;
        referalPerson[_battleId].joinerReferalPerson2 = _joinerReferalPerson2;
        referalPerson[_battleId].joinerReferalPerson3 = _joinerReferalPerson3;
        
        referalPerson[_battleId].joinerReferalAmount1 = referalAmount;
        referalPerson[_battleId].joinerReferalAmount2 = referalAmount;
        referalPerson[_battleId].joinerReferalAmount3 = referalAmount;

        genToken.transfer(_joinerReferalPerson1,referalAmount);
        genToken.transfer(_joinerReferalPerson2,referalAmount);
        genToken.transfer(_joinerReferalPerson3,referalAmount);

        ////////// Creator_Referal_section /////////////

        referalPerson[_battleId].creatorReferalAmount1 = referalAmount;
        referalPerson[_battleId].creatorReferalAmount2 = referalAmount;
        referalPerson[_battleId].creatorReferalAmount3 = referalAmount;

        genToken.transfer(referalPerson[_battleId].creatorReferalPerson1,referalAmount);
        genToken.transfer(referalPerson[_battleId].creatorReferalPerson2,referalAmount);
        genToken.transfer(referalPerson[_battleId].creatorReferalPerson3,referalAmount);


    }

    function calculateDeductedPercentage(uint256 _amount) public pure returns (uint256){

        uint256 _initialPercentage = 500; // 5 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateReferalPercentage(uint256 _amount) public pure returns (uint256){

        uint256 _initialPercentage = 100; // 1 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function calculateTreasuryPercentage(uint256 _amount) public pure returns (uint256){

        uint256 _initialPercentage = 200; // 2 %
        return _amount.mul(_initialPercentage).div(10000);
    }

     
    
/////////////////////////////////////////////////////////////////////////////////////

    function LeaveBattle(uint256 _battleId) public {
        
        ShortBattle storage battle = battles[_battleId];

        require(msg.sender == battle.creator,
            "You must be a part of a battle before leaving it.");
        require(!battle.leaved," battle creator Already leave the battle.");

        if(loanAmount[battle.creator] > 0){

            if(loanAmount[battle.creator] >= battle.stakeAmount){

                loanAmount[battle.creator] -= battle.stakeAmount;
            }
            else{

                uint256 sendAmount = battle.stakeAmount - loanAmount[battle.creator];
                stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,sendAmount);
                loanAmount[battle.creator] = 0;
            }
        }
        else{
            stakingHelpingContract.updatePalyerGenAmountPlusBonus(battle.creator,battle.stakeAmount);
        }
        battle.leaved = true;

        emit leaveBattle(battle.creator,_battleId,battle.stakeAmount);
    }

    function getAllCreatorBattleIds(address _playerAddress) external view returns (uint256[] memory){
        return creatorBattleIds[_playerAddress];
    }
    function getAllJoinerBattleIds(address _playerAddress) external view returns (uint256[] memory){
        return joinerBattleIds[_playerAddress];
    }

     // ================ Contract Info ==========

    function addContractBalance(uint256 _amount) external {
        genToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawContractBalance(uint256 _amount) external onlyOwner {
        genToken.transfer(msg.sender, _amount);
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return genToken.balanceOf(address(this));
    }

    function stopTheBattles(bool _stopThem) public onlyOwner {
        stopBattles = _stopThem;
    }
            
}
