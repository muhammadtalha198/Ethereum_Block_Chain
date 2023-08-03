
//SPDX-License-Identifier: MIT
pragma solidity >= 0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StakingContract is Ownable,Pausable {
    
    struct UserInfo {
      string[] nodeIds;
      uint256 totalStakedAmount;
      uint256 totalRewardAmount;
    }
    struct StakeInfo {
      bool staked;
      uint256 stakedAmount;
      uint256 lastRewardTransfer;
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
    mapping(address => UserInfo) public userInfo;
 
    uint256 public totalStakedTokens;
    
    
    event StakeEvent(
        address indexed userAddress,
        uint256 stakedAmount,
        uint256 totalStakedAmount,
        bool tokenStaked
    );
    event RewardEvent(
        address userAddress, 
        uint256 _rewardAmount,
        bool _rewairdPaid
    );


    function fillTreasury() external payable onlyOwner {
        require(msg.sender.balance >= msg.value, "insufficient balance.");
    }
    
    function stakeTokens(string memory _nodeId) external payable whenNotPaused {

        require(msg.sender.balance >= msg.value, "insufficient balance.");                                                                                                                               

        totalStakedTokens += msg.value;
        userInfo[msg.sender].totalStakedAmount += msg.value;
        userInfo[msg.sender].nodeIds.push(_nodeId);

        stakeInfo[msg.sender][_nodeId].stakedAmount = msg.value;
        stakeInfo[msg.sender][_nodeId].staked = true;

        emit StakeEvent(
            msg.sender, 
            stakeInfo[msg.sender][_nodeId].stakedAmount,
            userInfo[msg.sender].totalStakedAmount,
            stakeInfo[msg.sender][_nodeId].staked
        );
    }

    function unStakeTokens(string memory _nodeId) external whenNotPaused {

        uint256 _stakedAmount = stakeInfo[msg.sender][_nodeId].stakedAmount;
        
        require(stakeInfo[msg.sender][_nodeId].staked,"Token didnt staked.");
        require(address(this).balance >= _stakedAmount,"Refill Treasuery");
        
        userInfo[msg.sender].totalStakedAmount -= _stakedAmount ;
        stakeInfo[msg.sender][_nodeId].stakedAmount = 0;
        stakeInfo[msg.sender][_nodeId].staked = false;
        totalStakedTokens -= _stakedAmount;
        
        (bool success, ) = payable(msg.sender).call{value: _stakedAmount}("");
        require(success, "Withdrawal failure");
        

        emit StakeEvent(
            msg.sender, 
            _stakedAmount,
            userInfo[msg.sender].totalStakedAmount,
            stakeInfo[msg.sender][_nodeId].staked
        );
 
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
            uint256 _lastRewardTransfer = stakeInfo[_userAddress][_nodeId].lastRewardTransfer;
            
            require(block.timestamp > _lastRewardTransfer + 5 minutes, // change it in months
                    "This user get reward before Time");

            userRewardInfo[_rewardId].rewardPaid = true;
            userRewardInfo[_rewardId].rewardAmount = _rewardAmount; 
            userRewardInfo[_rewardId].rewardTransferdTime = block.timestamp;
            userInfo[msg.sender].totalRewardAmount += _rewardAmount;
            stakeInfo[msg.sender][_nodeId].lastRewardTransfer = block.timestamp; 

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

            emit RewardEvent(
                _userAddress,
                _rewardAmount,
                sendRewards.rewardPaid
            );
        }

        return rewardInfoList.length;
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

    function withdrawAmount(uint256 _amount,address _userAddress) external onlyOwner {
        require(address(this).balance >= _amount, "_amount must be less then Treasury.");
        (bool success, ) = payable(_userAddress).call{value: _amount}("");
        require(success, "Withdrawal failure");
    }

    function checkTreasuryBalance() external onlyOwner view returns (uint256) {
        return address(this).balance; 
    }
    
    function getNodeIds(address _userAddress) external view returns (string[] memory) {
        return userInfo[_userAddress].nodeIds;
    }
    
    function list() external view returns (RewardInfo[] memory) {
        return rewardInfoList;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

 
    receive() external payable {
    }

    
}
