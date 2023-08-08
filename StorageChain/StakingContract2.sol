
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";



contract StakingContract is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    struct UserInfo {
      string[] nodeIds;
      uint256 totalStakedAmount;
      uint256 totalRewardAmount;
    }
    struct StakeInfo {
      bool staked;
      uint256 stakedAmount;
      uint256 lastRewardTransfer;
      string[] rewardIds;
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
        string  nodeId,
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

    event Transfered(
      address indexed sender,
       uint256 value
    );


     constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }


    function fillTreasury() external payable {
        require(msg.sender.balance >= msg.value, "insufficient balance.");
        emit Transfered(msg.sender, msg.value);
    }
    
    function stakeTokens(string memory _nodeId) external payable whenNotPaused {

        require(msg.sender.balance >= msg.value, "insufficient balance.");                                                                                                                               
        require(msg.value > 50 wei, "stakeAmount must be greater then 50 wei.");                                                                                                                            
        require(!isNodeIdStaked(msg.sender, _nodeId), "nodeId already staked.");

        totalStakedTokens += msg.value;
        userInfo[msg.sender].totalStakedAmount += msg.value;
        userInfo[msg.sender].nodeIds.push(_nodeId);

        stakeInfo[msg.sender][_nodeId].stakedAmount = msg.value;
        stakeInfo[msg.sender][_nodeId].staked = true;

        emit StakeEvent(
            _nodeId,
            msg.sender, 
            stakeInfo[msg.sender][_nodeId].stakedAmount,
            userInfo[msg.sender].totalStakedAmount,
            stakeInfo[msg.sender][_nodeId].staked
        );
    }

    function isNodeIdStaked(address userAddress, string memory _nodeId) internal view returns (bool) {
        string[] memory nodeIds = userInfo[userAddress].nodeIds;
        uint256 idsLength = nodeIds.length;

        for (uint256 i = 0; i < idsLength; i++) {
            if (keccak256(bytes(nodeIds[i])) == keccak256(bytes(_nodeId))) {
                return true;
            }
        }
        return false;
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
            _nodeId,
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
            
            require(stakeInfo[_userAddress][_nodeId].staked,"Token didnt staked.");
            require(!isRewardIdAdded(_userAddress, _nodeId, _rewardId), "please use different rewardId.");
            require(block.timestamp > _lastRewardTransfer + 5 minutes, // change it in months
                    "This user get reward before Time");

            userRewardInfo[_rewardId].rewardPaid = true;
            userRewardInfo[_rewardId].rewardAmount = _rewardAmount; 
            userRewardInfo[_rewardId].rewardTransferdTime = block.timestamp;
            userInfo[_userAddress].totalRewardAmount += _rewardAmount;
            stakeInfo[_userAddress][_nodeId].lastRewardTransfer = block.timestamp; 
            stakeInfo[_userAddress][_nodeId].rewardIds.push(_rewardId); 

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

    function isRewardIdAdded(address userAddress, string memory _nodeId, string memory _rewardId) internal view returns (bool) {
        string[] memory rewardIds = stakeInfo[userAddress][_nodeId].rewardIds;
        uint256 idsLength = rewardIds.length;

        for (uint256 i = 0; i < idsLength; i++) {
            if (keccak256(bytes(rewardIds[i])) == keccak256(bytes(_rewardId))) {
                return true;
            }
        }
        return false;
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

    function checkTreasuryBalance() external view returns (uint256) {
        return address(this).balance; 
    }
    
    function getNodeIds(address _userAddress) external view returns (string[] memory) {
        return userInfo[_userAddress].nodeIds;
    }

    function getRewardIds(address _userAddress, string memory _nodeId) external view returns (string[] memory) {
        return stakeInfo[_userAddress][_nodeId].rewardIds;
    }
    
    function GetRewardInfoListlist() external view returns (RewardInfo[] memory) {
        return rewardInfoList;
    }

    function GetRewardInfoListlistLength() external view returns (uint256) {
        return rewardInfoList.length;
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

 
    receive() external payable {
      emit Transfered(msg.sender, msg.value);
    }

    
}

//0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 
// aaa => aa
// bbb => bb
// ccc => cc

//0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 
// sss => ss
// ddd => dd
// fff => ff

//0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db 
// eee => ee
// rrr => rr
// ttt => tt


//0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB 
// mmm => mm
// nnn => nn
// yyy => yy

// [[“sss”,“ss”,“0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2”,1000000000000000000,true,22],[“eee”,“ee”,“0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db”,1000000000000000000,true,22],[“sss”,“ss”,“0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2”,1000000000000000000,true,22]]
// [[“sss”,“ss”,“0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2”,1000000000000000000,true,22],[“eee”,“ee”,“0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db”,1000000000000000000,true,22]]
