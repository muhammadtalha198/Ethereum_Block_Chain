pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract BNBPriceConsumer {
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // Chainlink BNB/USD price feed address on Binance Smart Chain Mainnet
        priceFeed = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
    }

    function getBNBPrice() public view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }
}
