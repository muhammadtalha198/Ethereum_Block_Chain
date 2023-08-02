// Usecase of smart contract 
// We have to transfer rewards to those who has staked storage. 
// Storage Nodes can stake Native STOR Tokens and will Get rewarrds 
// Reward Calculattion will be on WebEnd
// Will be deployed on Storage chain
import "hardhat/console.sol";
//SPDX-License-Identifier: MIT

pragma solidity >= 0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";


contract StakingContract is Ownable {
    
    
    struct StakeInfo {
      bool staked;
      uint256 stakedAmount;
    }
      
    struct UserRewardInfo {
      bool rewardPaid;
      uint256 rewardAmount;
      uint256 rewardTransferdTime;
    }
    
    struct RewardInfo{
      string nodeId;
      string rewardId;
      address userAddress;
      uint256 rewardAmount;
      bool rewardPaid;
      uint256 rewardTransferdTime;
    }

    RewardInfo[] public rewardInfoList;



    mapping(address => mapping( string => StakeInfo)) public stakeInfo;
    mapping(string => UserRewardInfo) public userRewardInfo;
 
    uint256 public totalStakedTokens;
    
    
    function fillTreasury() external payable onlyOwner {
        
        require(msg.sender.balance >= msg.value, "insufficient balance.");
    }
    
    function stakeTokens(string memory _nodeId) external payable {

        require(msg.sender.balance >=msg.value, "insufficient balance.");                                                                                                                               

        totalStakedTokens += msg.value;

        stakeInfo[msg.sender][_nodeId].stakedAmount = msg.value;
        stakeInfo[msg.sender][_nodeId].staked = true;
    }

     

    function transferRewards(RewardInfo[] memory sendReward) external onlyOwner returns(uint256){
    
        uint256 totalReward;
        
        for (uint i =0;  i < sendReward.length; i++){
            totalReward += sendReward[i].rewardAmount;
        }
        
        require(address(this).balance >= totalReward,"Please Fill Treasuery.");
        for (uint i =0;  i < sendReward.length; i++) {
        
            string memory _nodeId = sendReward[i].nodeId;
            string memory _rewardId = sendReward[i].rewardId;
            uint256 _rewardAmount = sendReward[i].rewardAmount;
            address _userAddress = sendReward[i].userAddress;
            uint256 _amount = sendReward[i].rewardAmount;


            userRewardInfo[_rewardId].rewardPaid = true;
            userRewardInfo[_rewardId].rewardAmount = _amount; 
            userRewardInfo[_rewardId].rewardTransferdTime = block.timestamp;

            RewardInfo memory sendRewards;

            sendRewards.nodeId = _nodeId;
            sendRewards.rewardId = _rewardId;
            sendRewards.userAddress = _userAddress;
            sendRewards.rewardAmount= _rewardAmount;
            sendRewards.rewardPaid = true;
            sendRewards.rewardTransferdTime = block.timestamp;

            rewardInfoList.push(sendRewards);

            (bool success, ) = payable(_userAddress).call{value: _rewardAmount}("");
            require(success, "Withdrawal failure");
        }

        return rewardInfoList.length;
       
    }


    function list() external view returns (RewardInfo[] memory) {
        return rewardInfoList;
    }


     function OneMonthInfo(uint256 _startTime, uint256 _endTime) external view returns (RewardInfo[] memory) {
         
        RewardInfo[] memory _rewardInfoList =  new RewardInfo[](rewardInfoList.length);
        
        uint256 count;

        for (uint256 i = 0; i < rewardInfoList.length; i++) {
               
            if (rewardInfoList[i].rewardTransferdTime >= _startTime && rewardInfoList[i].rewardTransferdTime <= _endTime) {
                _rewardInfoList[count] = rewardInfoList[i]; 
                count++; 
            }
        }
        

        return _rewardInfoList;
    }


    function getUserInfo(
      address _userAddress,
      string memory _nodeId, 
      string memory _rewardId) public view returns(
        
        bool _staked,
        uint256 _stakedAmount,
        bool _rewardPaid,
        uint256 _rewardAmount,
        uint256 _rewardTransferdTime){

         _staked = stakeInfo[_userAddress][_nodeId].staked;
         _stakedAmount = stakeInfo[_userAddress][_nodeId].stakedAmount;
         _rewardPaid = userRewardInfo[_rewardId].rewardPaid;
         _rewardAmount = userRewardInfo[_rewardId].rewardAmount;
         _rewardTransferdTime = userRewardInfo[_rewardId].rewardTransferdTime;

        return(_staked,_stakedAmount,_rewardPaid,_rewardAmount,_rewardTransferdTime);
    }

    function checkTreasuryBalance() external onlyOwner view returns (uint256) {
        return address(this).balance; 
    }

 
    receive() external payable {
    }

    
}
// [["xyz","ppp","0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",10000]]
