// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FactoryMacketContract is Ownable {

    struct MarketInfo {
        address marketAddress;
        string eventDescription;
        uint256 endTime;
    }

    MarketInfo[] public markets;

    event MarketCreated(address indexed marketAddress, string eventDescription);


    constructor(address initialOwner) Ownable(initialOwner) {}


    // Function to create a new prediction market
    function createMarket(string memory eventDescription, uint256 endTime) external  {
        
        require(block.timestamp < endTime, "End time must be in the future");

        address newMarketAddress = address(new Market(eventDescription, endTime , msg.sender));
        markets.push(MarketInfo(newMarketAddress, eventDescription, endTime));

        emit MarketCreated(newMarketAddress, eventDescription);
    }

    // Function to get information about a specific market
    function getMarketInfo(uint256 index) external view returns (address, string memory, uint256) {
        
        require(index < markets.length, "Invalid index");
        
        MarketInfo memory market = markets[index];
        return (market.marketAddress, market.eventDescription, market.endTime);
    }

    // Function to get the total number of created markets
    function getNumberOfMarkets() external view returns (uint256) {
        return markets.length;
    }

}
// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FactoryMacketContract is Ownable {

    struct MarketInfo {
        address marketAddress;
        string eventDescription;
        uint256 endTime;
    }

    MarketInfo[] public markets;

    event MarketCreated(address indexed marketAddress, string eventDescription);


    constructor(address initialOwner) Ownable(initialOwner) {}


    // Function to create a new prediction market
    function createMarket(string memory eventDescription, uint256 endTime) external  {
        
        require(block.timestamp < endTime, "End time must be in the future");

        address newMarketAddress = address(new Market(eventDescription, endTime , msg.sender));
        markets.push(MarketInfo(newMarketAddress, eventDescription, endTime));

        emit MarketCreated(newMarketAddress, eventDescription);
    }

    // Function to get information about a specific market
    function getMarketInfo(uint256 index) external view returns (address, string memory, uint256) {
        
        require(index < markets.length, "Invalid index");
        
        MarketInfo memory market = markets[index];
        return (market.marketAddress, market.eventDescription, market.endTime);
    }

    // Function to get the total number of created markets
    function getNumberOfMarkets() external view returns (uint256) {
        return markets.length;
    }

}

