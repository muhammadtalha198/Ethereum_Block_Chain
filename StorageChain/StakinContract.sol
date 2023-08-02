// Usecase of smart contract
// We have to transfer rewards to those who has staked storage.
// Storage Nodes can stake Native STOR Tokens and will Get rewarrds
// Reward Calculattion will be on WebEnd
// Will be deployed on Storage chain

//SPDX-License-Identifier: MIT

pragma solidity >=0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {
    struct UserInfo {
        string[] nodeIds;
        uint256 totalStakedAmount;
    }

    struct StakeInfo {
        bool staked;
        uint256 stakedAmount;
        string[] rewardIds;
    }

    struct RewardInfo {
        bool rewardPaid;
        uint256 rewardAmount;
        uint256 rewardTransferdTime;
    }

    mapping(address => mapping(string => StakeInfo)) public stakeInfo;
    mapping(address => UserInfo) public userInfo;
    mapping(string => RewardInfo) public rewardInfo;

    uint256 public totalStakedTokens;

    function fillTreasury() external payable onlyOwner {
        require(msg.value > 0, "Invalid Amount");
    }

    function stakeTokens(string memory _nodeId) external payable {
        require(msg.value > 0, "Cannot stake 0");

        totalStakedTokens += msg.value;
        userInfo[msg.sender].totalStakedAmount += msg.value;
        userInfo[msg.sender].nodeIds.push(_nodeId);

        stakeInfo[msg.sender][_nodeId].stakedAmount = msg.value;
        stakeInfo[msg.sender][_nodeId].staked = true;
    }

    struct SendReward {
        string nodeId;
        string rewardId;
        address userAddress;
        uint256 rewardAmount;
    }

    function transferRewards(
        SendReward[] memory sendReward
    ) external payable onlyOwner {
        for (uint i = 0; i < sendReward.length; i++) {
            string memory _nodeId = sendReward[i].nodeId;
            string memory _rewardId = sendReward[i].rewardId;
            uint _amount = sendReward[i].rewardAmount;
            address _address = sendReward[i].userAddress;

            (bool success, ) = payable(_address).call{value: _amount}("");
            require(success, "Withdrawal failure");

            stakeInfo[_address][_nodeId].rewardIds.push(_rewardId);
            rewardInfo[_rewardId].rewardPaid = true;
            rewardInfo[_rewardId].rewardAmount;
            rewardInfo[_rewardId].rewardTransferTime = block.timestamp;
        }
    }

    function getNodeIds(
        address _userAddress
    ) external view returns (string[] memory) {
        return userInfo[_userAddress].nodeIds;
    }

    function getUserRewads(
        address _userAddress,
        string memory _nodeId
    ) external view returns (string[] memory) {
        return stakeInfo[_userAddress][_nodeId].rewards;
    }

    receive() external payable {}
}
