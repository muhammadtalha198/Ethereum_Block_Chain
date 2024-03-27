// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
}

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
     IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;
    address public stakingContractAddress;

    uint256 public basePercent ;
    uint256 public maxWalletLimit;
    uint256 public maxBurning;
    uint256 public totalBurning;
    bool public liquidityAdded;
    
    mapping(address => bool) public blackListed;

    event updated(bool _updated);
    
    constructor(address initialOwner) ERC20("KGCToken", "KGC") Ownable(initialOwner) {

        basePercent = 10;
        _mint(initialOwner,99000 * 1e18);
        maxBurning = 9000 * 1e18;  
        maxWalletLimit = 10000 * 1e18;

    }

    function addPairAddress(address _routerAddress, address _usdcAddress, address _stakingContractAddress) external onlyOwner {
        
        uniswapV2Router = IUniswapV2Router02(_routerAddress);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this),_usdcAddress);
        stakingContractAddress = _stakingContractAddress;
        liquidityAdded = true;
    }

    function _transfer(address from, address to, uint256 value) internal virtual override {
            
        require(!blackListed[from], "You are blacklisted.");
        require(!blackListed[to], "Blacklisted address cannot receive tokens.");

        if(liquidityAdded){
            if ( to != owner() && to != uniswapV2Pair && to != stakingContractAddress) {
               
                require(balanceOf(to) + (value) <= maxWalletLimit, "Receiver is exceeding maxWalletLimit");
            }
        }

    
        if ( from == owner() || to == owner() || from == stakingContractAddress || to == stakingContractAddress) {

            super._transfer(from, to, value);

        }
        else if ( totalBurning < maxBurning){

                
            uint256 haveToBurn = burnBasePercentage(value);
            totalBurning += haveToBurn;

            uint256 sendOnePercent = calculatePercentage(value, 100);
            uint256 remainingAmount = value - (sendOnePercent);

            _burn(from, haveToBurn);
            
            super._transfer(from, to, remainingAmount - haveToBurn);
            super._transfer(from, owner(), sendOnePercent);
        }
        else{
                
            uint256 sendOnePercent = calculatePercentage(value, 100);
            uint256 remainingAmount = value - (sendOnePercent);
            
            super._transfer(from, to, remainingAmount);
            super._transfer(from, owner(), sendOnePercent);
            
        }
    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }


    function burnBasePercentage(uint256 value) private view returns (uint256)  {

        return ((value * (basePercent)) / (10000)); 
    }

    
    function updateMaxBurning(uint256 burnAmount) external onlyOwner {    
        
        if(burnAmount < totalSupply()){      
            maxBurning = burnAmount;
        }
        emit updated(true);
    }

    function addInBlackList(address account) external onlyOwner {
        require(!blackListed[account], "account is already black listed.");
        blackListed[account] = true;

        emit updated(true);
    }
    
    function removeFromBlackList(address account) external  onlyOwner {
        
        require(blackListed[account], "account is not black listed.");
        blackListed[account] = false;
        
        emit updated(true);
    }

}
