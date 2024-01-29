

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPancakeRouter01 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}



contract TokenPriceCalculator {


    IPancakeRouter01 public pancakeRouter;
    // address routeraddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; BNBTestNet : PancakeSwapV2


    address public USDC;
    address public KGC;

    constructor(address _pancakeRouter){
        pancakeRouter = IPancakeRouter01(_pancakeRouter);

    }

    function getGenAmount(uint256 _usdcAmount) public view returns(uint256){
        
        address[] memory pathTogetKGC = new address[](2);
        pathTogetKGC[0] = USDC;
        pathTogetKGC[1] = KGC;

        uint256[] memory _kgcAmount;
        _kgcAmount = pancakeRouter.getAmountsOut(_usdcAmount,pathTogetKGC);

        return _kgcAmount[1];

    } 

    function getGenAmount1(uint256 _usdcAmount) public view returns (uint256) {
    address[] memory pathTogetKGC = new address[](2);
        pathTogetKGC[0] = USDC;
        pathTogetKGC[1] = KGC;
        uint256[] memory _kgcAmount = pancakeRouter.getAmountsOut(_usdcAmount, pathTogetKGC);


    return _kgcAmount[1];
}


    // how much busd aginst one gen.
    function getKGCPrice(uint256 _genAmount) public  view returns(uint256){
        
        address[] memory pathTogetKGCPrice = new address[](2);
        pathTogetKGCPrice[0] = KGC;
        pathTogetKGCPrice[1] = USDC;

        uint256[] memory _kgcPrice;
        _kgcPrice = pancakeRouter.getAmountsOut(_genAmount,pathTogetKGCPrice);

        return _kgcPrice[1];
    }

    function setToken(address token1, address token2) external {
            USDC = token1;
            KGC = token2;
    }

}
