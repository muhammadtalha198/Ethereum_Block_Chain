// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


interface IBEP20 {
    
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}


contract PreSale {
    
    using SafeMath for uint256;
    
    IBEP20 public busdToken;

    struct tokenBuyer {
        address userAddress;
        uint256 userTokens;
    }

    bool public presaleStarted;
    uint256 private totalBuyers;
    uint256 public preSalePrice;
    uint256 private totalSoldTokens;
    uint256 public presaleStartingTime;
    uint256 public presaleEndingTime;
    uint256 public preSaleCap = 100000 * 1e18;


    address public owner;
    address busdWalletAddress = 0x1D375435c8EfA3e489ef002d2d0B1E7Eb3CC62Fe; //add busd wallet address 

    mapping(uint256 => tokenBuyer) public tokenBuyerInfo;
    event preSellInfo(address buyer, uint256 getPrice, uint256 soldTokens);

    
    constructor(address _busdToken) {
        
        owner = msg.sender;
        preSalePrice = 10; // Price in USD (10 usd aginst one Gen)
        busdToken = IBEP20(_busdToken);
    }

    // need amount in Wei

    function sellInPreSale(uint256 _amount) external PresaleState {
        
        require(totalSoldTokens + _amount.mul(1e18) <= preSaleCap, "All genTokens are Sold.");
        uint256 totalPrice = _amount * (preSalePrice.mul(1e18));

        require(busdToken.balanceOf(msg.sender) >= totalPrice,
            "You donot have sufficienyt amount of usd token to buy Gen.");

        busdToken.transferFrom(msg.sender, busdWalletAddress, totalPrice);

        tokenBuyerInfo[totalBuyers].userAddress = msg.sender;
        tokenBuyerInfo[totalBuyers].userTokens = _amount.mul(1e18);

        totalBuyers++;
        totalSoldTokens += _amount.mul(1e18);

        emit preSellInfo(msg.sender, totalPrice, _amount.mul(1e18));
    }

    function getAllBuyersInfo() public view returns (tokenBuyer[] memory) {
       
        tokenBuyer[] memory buyerTokenInfo = new tokenBuyer[](totalBuyers);

        for (uint256 i = 0; i < totalBuyers; i++) {
            tokenBuyer memory _tokenBuyer = tokenBuyerInfo[i];
            buyerTokenInfo[i] = _tokenBuyer;
        }

        return buyerTokenInfo;
    }

    function getTotalBuyers() public view returns(uint256){
        return totalBuyers;
    }

    function getTokenBuyersInfo(uint256 _tokenBuyer) public view returns(address, uint256){
        return (tokenBuyerInfo[_tokenBuyer].userAddress, tokenBuyerInfo[_tokenBuyer].userTokens);
    }

    function getTotalSoldTokens() external view returns(uint256 _totalSoldTokens){
        return totalSoldTokens;
    }

    function setPreSalePrice(uint256 _newPrice) external onlyOwner {
        preSalePrice = _newPrice;
    }

    function startPreSale(bool _presaleStarted, uint256 _presaleEndingTime) public onlyOwner{
        
        presaleStarted = _presaleStarted;
        presaleEndingTime = _presaleEndingTime;
        presaleStartingTime = block.timestamp;
    }

    function setBusdWalletAddress (address _busdWalletAddress) external onlyOwner {
        busdWalletAddress = _busdWalletAddress;
    }

    modifier PresaleState() {
        
        require(presaleStarted, "PreSale is not startrd Yet");
        
        if (presaleStarted && (block.timestamp > presaleEndingTime)) {
            presaleStarted = false;
        }
        
        require(block.timestamp < presaleEndingTime, "Presale has been ended!");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }
}
