pragma solidity 0.8.17;

interface PreSale {

    function getTotalBuyers() external view returns(uint256);
    function getTokenBuyersInfo(uint256 _tokenBuyer) external view returns(address, uint256);
    function getTotalSoldTokens() external view returns(uint256);
}


interface IBEP20 {
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    function isWhiteListed(address _address) external view returns(bool);
}

interface StakingContract {

    function players(address _playerAddress) external view returns(uint256 walletLimit,
                                uint256 totalArenaTokens);
    
    function treasuryWallet() external view returns(address);
    function busdWallet() external view returns(address);
    function areenaInCirculation() external view returns(uint256);
    function totalAreena() external view returns(uint256);
    function BusdInTreasury() external view returns (uint256);
    function setTotalAreena(uint256 _totalAreena) external;
    function setAreenaInCirculation(uint256 _areenaInCirculation) external;
    function updatePalyerWalletLimit(address _playerAddress,uint256 _walletLimit) external;
    function updatePalyerGenAmountPlusBonus(address _playerAddress,uint256 _genAmount) external;
    function minusArenaAmount(address _playerAddress,uint256 _arenaTokens) external;

    
    
}

interface AirDrop{
    
}

interface PancakeRouter {

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

contract StakingHelpingContract is Ownable {

    using SafeMath for uint256;

    PreSale public preSale;
    IBEP20 public genToken;
    IBEP20 public busdToken;
    PancakeRouter public pancakeRouter;
    StakingContract public stakingContract;

    bool public saleEnabled;
    uint256 public saleEndTime;
    uint256 public saleStartTime;
    uint256 public genBonusPercentage;
    address mainStakingContractAddress;

    mapping(address => uint256) public areenaLastTransactionForGen;

    address public preSaleWallet = 0x6783db6859A1E971d07035fC2dA916b94c314E51;


    event SellThroughDashboard(bool bonusEnabled, uint256 _amount, uint256 _bonusAmount, uint256 _time);
    event SellThroughAreena(uint256 areenaPrice, uint256 _totalAmountOfGen, uint256 _AddedInCastle);
    event SendInPreSale(address sendFrom, uint256 _tokenAmount, address _receiverAddress);
    event SendDirectlyToCastle(address sendFrom, uint256 _tokenAmount, address _receiverAddress);

    constructor(address _genToken, address _busdToken, address _preSale, 
                address _pancakeRouter, address _stakingContract, address _mainStakingContractAddress) {
        
        genToken = IBEP20(_genToken);
        busdToken = IBEP20(_busdToken);
        preSale = PreSale(_preSale);
        stakingContract = StakingContract(_stakingContract);
        pancakeRouter = PancakeRouter(_pancakeRouter);
        mainStakingContractAddress = _mainStakingContractAddress;
        
    }



    //============================ PreSale Info ==========================

    function sendPreSaleTokens() external {

        uint256 length  = preSale.getTotalBuyers();

        for(uint i = 0; i<= length; i++){

            (address _playerAddress, uint256 _noOfTokens) = preSale.getTokenBuyersInfo(i);
            stakingContract.updatePalyerGenAmountPlusBonus(_playerAddress, _noOfTokens);
        }

        uint256 totalAmountToSend = preSale.getTotalSoldTokens();

        require(msg.sender == preSaleWallet, 
                "Only PreSale Wallet can send Presale tokens.");

        require(genToken.balanceOf(preSaleWallet) >= totalAmountToSend, 
                "Owner did not have sufficent amount of Gen tokens in his wallet to send.");
            
        uint256 allowedAmount = genToken.allowance(preSaleWallet, address(this));
            
        require(allowedAmount >= totalAmountToSend, 
                "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

        genToken.transferFrom(preSaleWallet, mainStakingContractAddress, totalAmountToSend); 

        emit SendInPreSale(preSaleWallet, totalAmountToSend, mainStakingContractAddress);
    }

    function setPreSaleWallet(address _preSaleWallet) onlyOwner external {
        preSaleWallet = _preSaleWallet;
    }


//================================Areena Functions ============================================


    function sellAreenaByGen(uint256 _areenaAmount) external {
       
        uint256 _realAreenaAmount = _areenaAmount.mul(1e18);

        (uint256 _oldWalletLimit,uint256 _oldTotalArenaTokens) = stakingContract.players(msg.sender);

        require(_oldTotalArenaTokens >= _realAreenaAmount,
            "You do not have sufficient amount of arena tokens to sell.");

        if (_oldWalletLimit == 0) {
            stakingContract.updatePalyerWalletLimit(msg.sender, 1 * 1e18);
        }

        require(_realAreenaAmount < _oldWalletLimit,"Please Buy Areena Boster To get All of your reward.");
        
        require(block.timestamp > areenaLastTransactionForGen[msg.sender],
            "You canot sell areena token again before 1 hours.");

        uint256 minSlipage = calculateMinSlippage(basePriceForGenSell);
        uint256 maxSlipage = calculateMaxSlippage(basePriceForGenSell);
           
        uint256 _genPrice = getGenPrice();
            
        if(_genPrice > (basePriceForGenSell - maxSlipage) && _genPrice < (basePriceForGenSell - minSlipage)){
            
            (uint256 areenaPriceInBusd, uint256 _totalAmountOfGen) =  calculateTotalgenthroughAreenaWithoutSlippage(_areenaAmount); //_areenaAmount in uint value
            uint256 amountAdd = calculateSellTax(_totalAmountOfGen);

            amountAdd = _totalAmountOfGen - amountAdd;

            require(genToken.balanceOf(stakingContract.treasuryWallet()) >= _totalAmountOfGen, 
                    "Owner did not have sufficent amount of Gen tokens in his wallet to send.");
                
            uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
            require(allowedAmount >= _totalAmountOfGen, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

            genToken.transferFrom(stakingContract.treasuryWallet(), mainStakingContractAddress, _totalAmountOfGen);
            stakingContract.updatePalyerGenAmountPlusBonus(msg.sender, amountAdd);
        
            uint256 areenaInCirculation = stakingContract.areenaInCirculation();
            areenaInCirculation -= _realAreenaAmount;
            stakingContract.setAreenaInCirculation(areenaInCirculation);
            
            stakingContract.minusArenaAmount(msg.sender,_realAreenaAmount);

            uint256 totalAreena = stakingContract.totalAreena();
            totalAreena += _realAreenaAmount;
            stakingContract.setTotalAreena(totalAreena);

            areenaLastTransactionForGen[msg.sender] = block.timestamp + 1 hours; //////////hours////////////////

            emit SellThroughAreena(areenaPriceInBusd,_totalAmountOfGen, amountAdd);           

        }else{
        
            require(_genPrice > (basePriceForGenSell - maxSlipage) && _genPrice < (basePriceForGenSell + minSlipage), 
                "To get better price Please Buy gen from pancake swap.");

            (uint256 areenaPriceInBusd, uint256 _totalAmountOfGen) =  calculateTotalgenthroughAreena(_areenaAmount);
            
            uint256 amountAdd = calculateSellTax(_totalAmountOfGen);

            amountAdd = _totalAmountOfGen - amountAdd; 

            require(genToken.balanceOf(stakingContract.treasuryWallet()) >= _totalAmountOfGen, 
                    "Owner did not have sufficent amount of Gen tokens in his wallet to send.");
                
            uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
            require(allowedAmount >= _totalAmountOfGen, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

            genToken.transferFrom(stakingContract.treasuryWallet(), mainStakingContractAddress, _totalAmountOfGen);
            stakingContract.updatePalyerGenAmountPlusBonus(msg.sender, amountAdd);
        
            uint256 areenaInCirculation = stakingContract.areenaInCirculation();
            areenaInCirculation -= _realAreenaAmount;
            stakingContract.setAreenaInCirculation(areenaInCirculation);

            stakingContract.minusArenaAmount(msg.sender,_realAreenaAmount);
            
            uint256 totalAreena = stakingContract.totalAreena();
            totalAreena += _realAreenaAmount;
            stakingContract.setTotalAreena(totalAreena);

            areenaLastTransactionForGen[msg.sender] = block.timestamp + 1 hours; //////////hours////////////////

            emit SellThroughAreena(areenaPriceInBusd,_totalAmountOfGen, amountAdd);
        }
    }

    // _areenaAmount will be in intiger value.
    function calculateTotalgenthroughAreena(uint256 _areenaAmount) public view returns(uint256 _busdAmount, uint256 amountOfGen) {
        
        _busdAmount = calculateAreenaPriceInBusdForGen(_areenaAmount); //_busdAmount will be in wei value.
        amountOfGen = getGenAmount(_busdAmount); //amountOfGen will be in wei value.
        
        return (_busdAmount,amountOfGen);
    }

    //_areenaAmount will be in intiger value.
    function calculateTotalgenthroughAreenaWithoutSlippage(uint256 _areenaAmount) public view returns(uint256 _busdAmount, uint256 amountOfGen) {
        
        _busdAmount = calculateAreenaPriceInBusdForGen(_areenaAmount); //_busdAmount will be in wei value.
        amountOfGen = (_busdAmount.mul(1e18)).div(basePriceForGenSell);   // amountOfGen will be in wei 
                                                                        
        return (_busdAmount,amountOfGen);
    }

     /* uint256 _areenaAmount will be in intiger value */
    function calculateAreenaPriceInBusdForGen(uint256 _areenaAmount) public view returns (uint256){
        
        uint256 _busdWalletBalance = stakingContract.BusdInTreasury();
        uint256 _areenaValue = _busdWalletBalance.div(10000);

        return _areenaAmount.mul(_areenaValue);
    }

//================================Gen Price calculation ============================================


    address public BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public GEN = 0x66807bFF998aAd2bD4cDDFFA36B12dF25CC754B1;

    uint256 public basePriceForGenSell = 10*1e18;
    address[] public pathTogetGen = [BUSD,GEN];
    address[] public pathTogetGenPrice = [GEN,BUSD];

    function getGenAmount(uint256 _busdAmount) public view returns(uint256){
        
        uint256[] memory _genAmount;
        _genAmount = pancakeRouter.getAmountsOut(_busdAmount,pathTogetGen);

        return _genAmount[1];
    } 

    // how much busd aginst one gen.
    function getGenPrice() public view returns(uint256){
        
        uint256 _genAmount = 1*1e18; 
        uint256[] memory _genPrice;
        
        _genPrice = pancakeRouter.getAmountsOut(_genAmount,pathTogetGenPrice);

        return _genPrice[1];
    }

    uint256 public minSlippage = 500;
    uint256 public  maxSlippage = 1500;

    function calculateMinSlippage(uint256 _amount) public view returns (uint256){
        return _amount.mul(minSlippage).div(10000);
    }

    function calculateMaxSlippage(uint256 _amount) public view returns (uint256){
        return _amount.mul(maxSlippage).div(10000);
    }


    function setbasePrice(uint256 _basePrice) external onlyOwner {
        basePriceForGenSell = _basePrice;
    }

    function setMinSlippage(uint256 _minSlippage) external onlyOwner {
        minSlippage = _minSlippage;
    }

    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        maxSlippage = _maxSlippage;
    }


//=====================================Sell Gen Through The Dashboard ====================================



    function sellGenThroughDashboard(uint256 _busdAmount) public {

        uint256 _realBusdAmount = _busdAmount.mul(1e18);

        require(busdToken.balanceOf(msg.sender) >= _realBusdAmount,
            "You do not have sufficent amount of busd to buy gen token.");

        uint256 minSlipage = calculateMinSlippage(basePriceForGenSell);
        uint256 maxSlipage = calculateMaxSlippage(basePriceForGenSell);
           
        uint256 _genPrice = getGenPrice();
            
        if(_genPrice > (basePriceForGenSell - maxSlipage) && _genPrice < (basePriceForGenSell - minSlipage)){

            uint256 totalGenAmount = (_realBusdAmount.mul(1e18)).div(basePriceForGenSell); 

            uint256 amountAdd = calculateSellTax(totalGenAmount);
            amountAdd = totalGenAmount - amountAdd;
  
            require(genToken.balanceOf(stakingContract.treasuryWallet()) >= totalGenAmount,
                "treasury wallet didnt have sufficient amount of gen token to sell right now.");

            if (saleEnabled && (block.timestamp > saleEndTime)) {
                saleEnabled = false;
            }

            bool checkWhiteListed = genToken.isWhiteListed(msg.sender);

            if (saleEnabled && (block.timestamp < saleEndTime)) {
                
                uint256 bonusAmount = calculateGenBonusPercentage(totalGenAmount);

                busdToken.transferFrom(msg.sender, stakingContract.busdWallet(), _realBusdAmount);
                
                uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
                require(allowedAmount >= totalGenAmount, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

                genToken.transferFrom(stakingContract.treasuryWallet(),mainStakingContractAddress,totalGenAmount);

                if(checkWhiteListed == true){

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender, totalGenAmount.add(bonusAmount));
                    emit SellThroughDashboard(true, totalGenAmount, bonusAmount, block.timestamp);
                }else{

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender, amountAdd.add(bonusAmount));
                    emit SellThroughDashboard(true, amountAdd, bonusAmount, block.timestamp);
                }

                
            } else {

                busdToken.transferFrom(msg.sender, stakingContract.busdWallet(), _realBusdAmount);

                uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
                require(allowedAmount >= totalGenAmount, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

                genToken.transferFrom(stakingContract.treasuryWallet(),mainStakingContractAddress,totalGenAmount);

                if(checkWhiteListed == true){

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,totalGenAmount);
                    emit SellThroughDashboard(false, totalGenAmount, 0, block.timestamp);
                }
                else{

                     stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,amountAdd);
                    emit SellThroughDashboard(false, amountAdd, 0, block.timestamp);
                }

            }            

        }else{
            
            require(_genPrice > (basePriceForGenSell - maxSlipage) && _genPrice < (basePriceForGenSell + minSlipage), 
                "To get better price Please Buy gen from pancake swap.");

            uint256 totalGenAmount = getGenAmount(_realBusdAmount); 

            uint256 amountAdd = calculateSellTax(totalGenAmount);
            amountAdd = totalGenAmount - amountAdd;

            require(genToken.balanceOf(stakingContract.treasuryWallet()) >= totalGenAmount,
                "treasury wallet didnt have sufficient amount of gen token to sell right now.");

            if (saleEnabled && (block.timestamp > saleEndTime)) {
                saleEnabled = false;
            }

            bool checkWhiteListed = genToken.isWhiteListed(msg.sender);

            if (saleEnabled && (block.timestamp < saleEndTime)) {
                
                uint256 bonusAmount = calculateGenBonusPercentage(totalGenAmount);

                busdToken.transferFrom(msg.sender, stakingContract.busdWallet(), _realBusdAmount);
                
                uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
                require(allowedAmount >= totalGenAmount, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

                genToken.transferFrom(stakingContract.treasuryWallet(),mainStakingContractAddress,totalGenAmount);

                if(checkWhiteListed == true){

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,totalGenAmount.add(bonusAmount)); 
                    emit SellThroughDashboard(true, totalGenAmount, bonusAmount, block.timestamp);
                }else{

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,amountAdd.add(bonusAmount));
                    emit SellThroughDashboard(true, amountAdd, bonusAmount, block.timestamp);
                }

                
            } else {

                busdToken.transferFrom(msg.sender, stakingContract.busdWallet(), _realBusdAmount);

                uint256 allowedAmount = genToken.allowance(stakingContract.treasuryWallet(), address(this));
                
                require(allowedAmount >= totalGenAmount, 
                    "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

                genToken.transferFrom(stakingContract.treasuryWallet(),mainStakingContractAddress,totalGenAmount);

                if(checkWhiteListed == true){

                    stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,totalGenAmount);
                    emit SellThroughDashboard(false, totalGenAmount, 0, block.timestamp);
                }
                else{

                   stakingContract.updatePalyerGenAmountPlusBonus(msg.sender,amountAdd);
                    emit SellThroughDashboard(false, amountAdd, 0, block.timestamp);
                }

            }

        }
        
    }

    function calculateSellTax(uint256 _amount) public pure returns (uint256) {
        uint256 _initialPercentage = 1600; // 16 %
        return _amount.mul(_initialPercentage).div(10000);
    }

    function enableTheBonus(bool _enable, uint256 _endingTime,  uint256 _percentage) public onlyOwner {
        
        saleEnabled = _enable;
        saleEndTime = _endingTime;
        saleStartTime = block.timestamp;
        genBonusPercentage = _percentage;
        
    }

    function calculateGenBonusPercentage(uint256 _amount) public view returns (uint256){
        
        uint256 _initialPercentage = genBonusPercentage.mul(100);
        return _amount.mul(_initialPercentage).div(10000);
    }

    function sendSellGenThroughDashboardInformation() public view returns(bool, uint256, uint256, uint256){
        return(saleEnabled, genBonusPercentage, saleStartTime, saleEndTime);

    }

    function sendDirectlyToCastle(address[] memory _playerAddresses, uint256[] memory _tokenAmounts) public {
        
        uint256 totalAmountOfTokens;

         require(_playerAddresses.length == _tokenAmounts.length,"addresses & amounts length should be same.");

        
        for(uint i=0; i < _playerAddresses.length; i++){
            stakingContract.updatePalyerGenAmountPlusBonus(_playerAddresses[i],_tokenAmounts[i]);
            totalAmountOfTokens += _tokenAmounts[i];
        }

        require(genToken.balanceOf(msg.sender) >= totalAmountOfTokens, 
                "You did not have sufficent amount of Gen tokens in his wallet to send.");
            
        uint256 allowedAmount = genToken.allowance(msg.sender, address(this));
            
        require(allowedAmount >= totalAmountOfTokens, 
                "You must have allowed the contract to spent that particular amount of Gen tokens.");

        genToken.transferFrom(msg.sender, mainStakingContractAddress, totalAmountOfTokens); 

        emit SendDirectlyToCastle(msg.sender, totalAmountOfTokens, mainStakingContractAddress);

    }

    function sendDirectlyToWallets(address[] memory _playerAddresses, uint256[] memory _tokenAmounts) public {
        
        uint256 totalAmountOfTokens;

        require(genToken.balanceOf(msg.sender) >= totalAmountOfTokens, 
                "Owner did not have sufficent amount of Gen tokens in his wallet to send.");
            
        uint256 allowedAmount = genToken.allowance(msg.sender, address(this));
            
        require(allowedAmount >= totalAmountOfTokens, 
                "Owner must have allowed the contract to spent that particular amount of Gen tokens.");

        require(_playerAddresses.length == _tokenAmounts.length,"addresses & amounts length should be same.");
        
        for(uint i=0; i < _playerAddresses.length; i++){
            genToken.transferFrom(msg.sender, _playerAddresses[i], _tokenAmounts[i]);
            totalAmountOfTokens += _tokenAmounts[i];
        }

        emit SendDirectlyToCastle(msg.sender, totalAmountOfTokens, mainStakingContractAddress);

    }


}