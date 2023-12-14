// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "hardhat/console.sol";

// console.log("",);

interface MintingContract{

    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address);
    function getFiscalSponsor(address _organizationAddress) external view returns (bool,uint256, address, address);
}


interface WMATIC {
    
    function balanceOf(address personAddress) external returns (uint256);
    function allowance(address proverAddress, address approvedAddress ) external returns (uint256);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract Marketplace is 
    Initializable, 
    ERC1155HolderUpgradeable ,
    OwnableUpgradeable, 
    UUPSUpgradeable ,  
    PausableUpgradeable {

    using SafeMathUpgradeable for uint256;
    MintingContract public mintingContract;
    WMATIC public wMatic; 
    
    uint256 public listId;
    address payable public marketPlaceOwner;
    uint256 public serviceFeePercentage;
    address public mintingContractAddress;

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
 
    function initialize(address _mintingContract,address _wrappedMaticAddress) initializer public {

        serviceFeePercentage = 250; 
        marketPlaceOwner = payable(msg.sender);
        mintingContractAddress = _mintingContract;
        mintingContract = MintingContract(_mintingContract);
        wMatic = WMATIC(_wrappedMaticAddress);


        __Pausable_init();
        __ERC1155Holder_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
       
    }

     struct List {

        bool listed;
        bool nftClaimed;
        bool fixedPrice;
        uint256 price;
        uint256 heighestBid;
        uint256 tokenId;
        uint256 noOfCopies;
        address nftOwner;
        address newOwner;
        address nftAddress;
        uint256 listingEndTime;      
        uint256 listingStartTime;
        uint256[] currentBidAmount;
        address[] currentBidder;
    }

    struct DonationInfo{

        uint256 noOfOrgazisations;
        address[3] organizations;
        uint256[3] donatePercentages;
    }

    struct BidInfo{

        bool bided;
        uint256 bidNo;
    }


    mapping (uint256 => List) public listing;
    mapping (uint256 => DonationInfo) public donationInfo;
    mapping (uint256 => mapping(address => BidInfo)) public bidInfo;


    event CancelBid(bool bided, uint256 _heigestBidAmount);
    event Bided(address _currentBidder, uint256 _bidAmount, uint256 __heigestBidAmount);
    event plateFarmFeePercentage(uint256 _serviceFeePercentage,address _owner);
    event Edited (uint256 _initialPrice,uint256 _listStartTime,uint256 _listEndTime);
    event SoldNft(address _from,uint256 indexed _tokenId,address indexed _nftAddress,address _to,uint256 _noOfCopirs);
    event FeeInfo(uint256 fiscalFee, uint256 royaltyFee,uint256 indexed serviceFee,uint256 indexed donationFee, uint256 indexed amountSendToSeller);
    event Listed(uint256 _listId,uint256 _tokenId, uint256 _noOfCopies, uint256 _initialPrices);
    
    //--List item for list--------------------------------------------------------------------/

    function listForUsers(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address[] memory _organizations,
        uint256[] memory _donatePercentages
    ) external checkOrganizations( _organizations,_donatePercentages) {

        listId++;
        
        setListingInfo(_tokenId,_noOfCopies,_initialPrice,_listStartTime,_listEndTime,_nftAddress);    
        setDonationInfo(listId, _organizations, _donatePercentages);

        if(_nftAddress != mintingContractAddress){

            setMintingAddress( _tokenId, _noOfCopies,  listId,  _nftAddress);
        }else{
            setMintingAddress( _tokenId, _noOfCopies,  listId,  mintingContractAddress); 
        }

        emit Listed(
            listId,
            _tokenId, 
            _noOfCopies,
            _initialPrice
        );
    }

   
    function listForOrganizations(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address _fiscalSponsor
    ) external checkFiscalSponsor(_fiscalSponsor){

       listId++;

       setListingInfo(_tokenId,_noOfCopies,_initialPrice,_listStartTime,_listEndTime,_nftAddress);
        

        if(_nftAddress != mintingContractAddress){

            setMintingAddress( _tokenId, _noOfCopies,  listId,  _nftAddress);
        }else{

            setMintingAddress( _tokenId, _noOfCopies,  listId,  mintingContractAddress); 
        }

        emit Listed(
            listId,
            _tokenId, 
            _noOfCopies,
            _initialPrice
        );

   }

    function editList(
        uint256 _listId, 
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime ) external  {

        require(_listId > 0,"inavlid list id");
        require(listing[_listId].listed, "nft isnt listed yet.");
        require(!listing[_listId].nftClaimed,"Nft already sold");
        require(msg.sender == listing[_listId].nftOwner ,"onlynftOwner of this nft can edit.");


        setListingInfo(
            
            listing[_listId].tokenId,
            listing[_listId].noOfCopies,
            _initialPrice,
            _listStartTime,
            _listEndTime,
            listing[_listId].nftAddress
        );
        
        emit Edited (
            listing[_listId].price,
            listing[_listId].listingStartTime,
            listing[_listId].listingEndTime
        );

    }

  
    // Buy Fixed Price---------------------------------------------------------------------------------------------------
    function BuyFixedPriceItem(uint256 _listId) payable external checkSell(_listId) whenNotPaused { 

        require(msg.value >=  listing[_listId].price,
            "invalid fee.");
        
        require(listing[_listId].fixedPrice,"Its on auction!");

        listing[_listId].newOwner = msg.sender;

        console.log("no 1 ");

        
        console.log("listing[_listId].price: ", listing[_listId].price);
        console.log("serviceFeePercentage: ", serviceFeePercentage);
        
        uint256 serviceFee = calulateFee(listing[_listId].price, serviceFeePercentage);

        console.log("servic eFee : ", serviceFee);

        uint256 donationFee;
        
        if(donationInfo[_listId].noOfOrgazisations > 0){

            console.log(" donationFee ", donationFee);

           donationFee =  donationFeeTransfer(_listId, true); 

            console.log("no 2 donationFee ", donationFee); 

        }

        uint256 fiscalFee = getFiscalFee(_listId);

        console.log(" fiscalFee:  ", fiscalFee);
        
        uint256 royaltyFee = getRoyalityFee(_listId);

        console.log(" royaltyFee : ",royaltyFee);

        console.log("listing[_listId].price: ", listing[_listId].price);
       
        uint256 amountSendToSeller = listing[_listId].price.sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));


        console.log("amountSendToSeller", amountSendToSeller);

        transferFundsInEth(payable (marketPlaceOwner) ,serviceFee);

        console.log("no 22222 ");
        transferFundsInEth(payable(listing[_listId].nftOwner) , amountSendToSeller);
        

        console.log("no 3333333 ");

        listing[_listId].nftClaimed = true;

        console.log("no 4444444 ");
        
        transferNft(
            listing[_listId].nftAddress,
            address(this),
            listing[_listId].newOwner, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        );

        emit SoldNft(
            address(this),
            listing[_listId].tokenId,
            listing[_listId].nftAddress,
            listing[_listId].newOwner,
            listing[_listId].noOfCopies);

        emit FeeInfo(
            fiscalFee,
            royaltyFee,
            serviceFee,
            donationFee,
            amountSendToSeller);
    }



    function startBid( uint256 _listId, uint256 _bidPrice)  external checkSell(_listId) whenNotPaused {

        require(!listing[_listId].fixedPrice,"Its on fixedPrice!");
        require(_bidPrice > 0,"inavlid _bidPrice");
        require(wMatic.balanceOf(msg.sender) >= _bidPrice, 
            "insufficent balance.");
        
        require(block.timestamp > listing[_listId].listingStartTime,
            "you canot bid before list started.");

        require(_bidPrice > listing[_listId].heighestBid,
            "There is already higer or equal bid exist" );

            console.log("_bidPrice: ",_bidPrice);
       
        if(_bidPrice > listing[_listId].heighestBid){
            listing[_listId].heighestBid = _bidPrice;
        }

        console.log("listing[_listId].heighestBid: ",listing[_listId].heighestBid);

        require(wMatic.allowance(msg.sender,address(this)) >= _bidPrice,"Approve that amount before bid.");


        console.log("bidInfo[_listId][msg.sender].bided ",bidInfo[_listId][msg.sender].bided);

        if(bidInfo[_listId][msg.sender].bided){
            cancelBid( _listId);
            console.log("canceled:  ",true);

        }

         console.log("33333333:  ");
       
        listing[_listId].currentBidder.push(msg.sender);
        listing[_listId].currentBidAmount.push(_bidPrice);

    console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidder.length);
    console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidder.length - 1);
    
    console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidder[listing[_listId].currentBidder.length]);
    console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidder[listing[_listId].currentBidder.length - 1]);


    console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidAmount.length);
     console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidAmount.length - 1);
    
        console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidAmount[listing[_listId].currentBidAmount.length]);
        console.log("listing[_listId].currentBidder:  ", listing[_listId].currentBidAmount[listing[_listId].currentBidAmount.length - 1]);
        
        bidInfo[_listId][msg.sender].bidNo = listing[_listId].currentBidder.length;
        bidInfo[_listId][msg.sender].bided = true;

        console.log("listing[_listId].currentBidder:  ",  bidInfo[_listId][msg.sender].bidNo);


        emit Bided(
            listing[_listId].currentBidder[listing[_listId].currentBidder.length - 1],
            listing[_listId].currentBidAmount[listing[_listId].currentBidAmount.length - 1],
            listing[_listId].heighestBid
            );

    }

    function cancelBid(uint256 _listId) public   {

        require(_listId > 0,"inavlid list id");
        require(listing[_listId].listed, "nft isnt listed yet.");
        require(!listing[_listId].nftClaimed,"Nft already sold");
        require(bidInfo[_listId][msg.sender].bided,"You didndt Bid.");

        bidInfo[_listId][msg.sender].bided = false;
        
        uint256 _bidNo = bidInfo[_listId][msg.sender].bidNo;

        listing[_listId].currentBidAmount[_bidNo] = 0;
        listing[_listId].currentBidder[_bidNo] = address(0);
       
        if(listing[_listId].currentBidAmount[_bidNo] ==  listing[_listId].heighestBid){
            
            for(uint i = listing[_listId].currentBidAmount.length - 1; i >= 0; i--){
                if(listing[_listId].currentBidAmount[i] != 0){
                   listing[_listId].heighestBid =  listing[_listId].currentBidAmount[i];
                   break;
                }
            }
        }

        emit CancelBid(bidInfo[_listId][msg.sender].bided, listing[_listId].heighestBid );
    }



    function acceptOffer(uint256 _listId, uint256 _bidNo) external  whenNotPaused {

        require(_listId > 0,"inavlid list id");
        require(listing[_listId].listed, "nft isnt listed yet.");
        require(!listing[_listId].nftClaimed,"Nft already sold");
        require(!listing[_listId].fixedPrice,"Its on fixedPrice!");

        console.log("no 1 ");

        
        console.log("listing[_listId].price: ", listing[_listId].price);
        console.log("serviceFeePercentage: ", serviceFeePercentage);

        uint256 serviceFee = calulateFee(listing[_listId].currentBidAmount[_bidNo], serviceFeePercentage);
        

        console.log("servic eFee : ", serviceFee);


        uint256 donationFee;

        if(donationInfo[_listId].noOfOrgazisations > 0){

             console.log(" donationInfo[_listId].noOfOrgazisations:  ", donationInfo[_listId].noOfOrgazisations);
           
            donationFee =  donationFeeTransfer(_listId, false);

            console.log("no 2 donationFee ", donationFee);
        }



        uint256 fiscalFee = getFiscalFee(_listId);

         console.log(" fiscalFee:  ", fiscalFee);

        uint256 royaltyFee = getRoyalityFee(_listId);

        console.log(" royaltyFee : ",royaltyFee);

        console.log("listing[_listId].price: ", listing[_listId].price);

        uint256 amountSendToSeller = listing[_listId].currentBidAmount[_bidNo].sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));


        console.log("amountSendToSeller", amountSendToSeller);


        address _currentBidder = listing[_listId].currentBidder[_bidNo];

        console.log("_currentBidder: ", _currentBidder);
        console.log("marketPlaceOwner", marketPlaceOwner);
        console.log("serviceFee", serviceFee);


        transferFundsInWEth(_currentBidder,marketPlaceOwner ,serviceFee);

        console.log("no 22222 ");
        transferFundsInWEth(_currentBidder,listing[_listId].nftOwner , amountSendToSeller);


        console.log("no 3333333 ");

        listing[_listId].nftClaimed = true;
        listing[_listId].newOwner = _currentBidder;


        console.log("no 4444444 ");


        transferNft(
            listing[_listId].nftAddress,
            address(this),
            _currentBidder, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        ); 

        emit SoldNft(
            address(this),
            listing[_listId].tokenId,
            listing[_listId].nftAddress,
           _currentBidder,
            listing[_listId].noOfCopies);

        emit FeeInfo(
            fiscalFee,
            royaltyFee,
            serviceFee,
            donationFee,
            amountSendToSeller);              
    }

    function cancellListingForlist(uint256 _listingID) external {

        require(msg.sender == listing[_listingID].nftOwner , "You are not the nftOwner");
        require(!listing[_listingID].nftClaimed,"NFT is alrady sold,");
        
        setCancelList(_listingID);
        
        transferNft(
            listing[_listingID].nftAddress,
            address(this),
            listing[_listingID].nftOwner, 
            listing[_listingID].tokenId, 
            listing[_listingID].noOfCopies
        );

    }


    function setPlatFormServiceFeePercentage(uint256 _serviceFeePercentage) external onlyOwner{
        require( _serviceFeePercentage >=100  && _serviceFeePercentage <= 1000, 
            "fee % must between in 1% to 10% ");

        serviceFeePercentage = _serviceFeePercentage;
        
        emit plateFarmFeePercentage(serviceFeePercentage,msg.sender);
    }


    function setDonationInfo(uint256 _priceId,address[] memory _organizations,uint256 [] memory _donatePercentages) private {

        for(uint256 i=0; i < _organizations.length; i++){
            
            if(_organizations[i] != address(0)){
                donationInfo[_priceId].organizations[i] = _organizations[i];
                donationInfo[_priceId].donatePercentages[i] = _donatePercentages[i];
                donationInfo[_priceId].noOfOrgazisations += 1;
            }
        }
    }

     function setListingInfo(
        uint256 _tokenId,
        uint256 _noOfCopies,
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        address _nftAddress) 
        
        private checkForList (
            _initialPrice,
            _listStartTime,
            _listEndTime,
            _tokenId,
            _noOfCopies,
            _nftAddress) 
        {

        if(_listStartTime == 0 && _listEndTime == 0){
            listing[listId].fixedPrice  =  true;
        }

        listing[listId].listed = true;
        listing[listId].tokenId = _tokenId;
        listing[listId].noOfCopies = _noOfCopies;
        listing[listId].price = _initialPrice;
        listing[listId].listingStartTime = _listStartTime;
        listing[listId].listingEndTime = _listEndTime;
        listing[listId].nftOwner = msg.sender;
    }

    function donationFeeTransfer(uint256 _listId, bool _inEth) private returns (uint256) {

        uint256 totalDonationAmount = 0;

        for (uint256 i = 0; i < donationInfo[_listId].noOfOrgazisations; i++) {
           
            if ( donationInfo[_listId].organizations[i] != address(0)) {
               
                uint256 donationAmount = calulateFee(listing[_listId].price,  donationInfo[_listId].donatePercentages[i]);
               
                if (_inEth) {
                    transferFundsInEth(payable(donationInfo[_listId].organizations[i]), donationAmount);
                } else {
                    transferFundsInWEth(listing[_listId].currentBidder[listing[_listId].currentBidder.length - 1], donationInfo[_listId].organizations[i], donationAmount);
                }
                totalDonationAmount += donationAmount;
            }
        }

        console.log("no 1 donationFee orignal: ", totalDonationAmount);
        return totalDonationAmount;
    }

    function getFiscalFee(uint256 _listId) private returns (uint256){

        uint256 fiscalFee;
        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _fiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);

        if(_haveSponsor){
            
            fiscalFee = calulateFee(listing[_listId].price, _fiscalSponsorPercentage);
            transferFundsInEth(payable(_fiscalSponser),fiscalFee);
        }

        return fiscalFee;
    }

    function getRoyalityFee(uint256 _listId) private returns (uint256){

        uint256 royaltyFee;
        
        if(mintingContractAddress == listing[_listId].nftAddress){

            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(listing[_listId].tokenId);

            royaltyFee = calulateFee(listing[_listId].price, _royaltyPercentage);
            transferFundsInEth(payable(_royaltyReciver),royaltyFee);

        }

        console.log("royaltyFee original : ", royaltyFee);
        return royaltyFee;
    }



    function setMintingAddress(uint256 _tokenId,uint256 _noOfCopies, uint256 priceId, address setAddress) private {

        listing[priceId].nftAddress = setAddress;

        transferNft(
            setAddress,
            msg.sender,
            address(this), 
            _tokenId, 
            _noOfCopies
        );

    }

    function transferNft(
        address _nftAddress,
        address _from, 
        address _to, 
        uint256 _tokenId,  
        uint256 _noOfcopies
    ) private {


        console.log("TRANSFER ");

         IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                _from,
                _to,
                _tokenId,
                _noOfcopies,
                '0x00'
            );

    }

    function setCancelList(uint256 _listingID) private {
        listing[_listingID].fixedPrice = false;
        listing[_listingID].listed = false;
        listing[_listingID].tokenId = 0;
        listing[_listingID].noOfCopies = 0;
        listing[_listingID].price = 0;
        listing[_listingID].listingEndTime = 0;
        listing[_listingID].listingStartTime = 0;
        listing[_listingID].nftAddress = address(0);
        listing[_listingID].nftOwner = address(0);
        // listing[_listingID].currentBidAmount = 0;
        // listing[_listingID].currentBidder = address(0);
    }

    function calulateFee(uint256 _salePrice , uint256 _serviceFeePercentage) private pure returns(uint256){
        
        require(_salePrice !=0 , "Price of NFT can not be zero");
        require(_serviceFeePercentage !=0 , "_PBP can not be zero");
        
        uint256 serviceFee = _salePrice.mul(_serviceFeePercentage).div(10000);

        console.log("serviceFee origginal : ", serviceFee);
        
        return serviceFee;
    }

    function transferFundsInEth(address payable _recipient, uint256 _amount) private {

        // console.log("_recipient : ",_recipient);
        // console.log("_amount : ",_amount);
        payable(_recipient).transfer(_amount); 

        //   (bool success, ) = _recipient.call{value: _amount}("");
        // require(success, "Transfer failed");

        // bool success = _recipient.send(_amount);
        // require(success, "Transfer fee failed");
    }

    function transferFundsInEthTransfer(address payable _recipient, uint256 _amount) public payable{

        // console.log("_recipient : ",_recipient);
        // console.log("_amount : ",_amount);
        payable(_recipient).transfer(_amount); 

        //   (bool success, ) = _recipient.call{value: _amount}("");
        // require(success, "Transfer failed");

        // bool success = _recipient.send(_amount);
        // require(success, "Transfer fee failed");
    }

     function transferFundsInEthCall(address payable _recipient, uint256 _amount) public payable {

        // console.log("_recipient : ",_recipient);
        // console.log("_amount : ",_amount);
        // payable(_recipient).transfer(_amount); 

          (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Transfer failed");

        // bool success = _recipient.send(_amount);
        // require(success, "Transfer fee failed");
    }

     function transferFundsInEthSend(address payable _recipient, uint256 _amount) public  payable {

        // console.log("_recipient : ",_recipient);
        // console.log("_amount : ",_amount);
        // payable(_recipient).transfer(_amount); 

        //   (bool success, ) = _recipient.call{value: _amount}("");
        // require(success, "Transfer failed");

        bool success = _recipient.send(_amount);
        require(success, "Transfer fee failed");
    }

    function transferFundsInWEth(address _src,address _recipient, uint256 _amount) private {
        (bool success) = wMatic.transferFrom(_src, _recipient, _amount);
        require(success, "Transfer  fee failed");
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


    modifier checkOrganizations(address[] memory _organizations,uint256[] memory _donatePercentages){
            
        require(_organizations.length >= 1 && _organizations.length <= 3,"you can chose one to three organizations.");
        require(_organizations.length == _donatePercentages.length, "invalid organizations input.");
        
        bool atleastOne;
        for(uint i=0; i < _organizations.length; i++){
            if(_organizations[i] != address(0)){

                require(_donatePercentages[i] >= 500 && _donatePercentages[i] <= 10000,
                    "donation percentage must be between 5 to 100");
                atleastOne = true;
            }
        }

        require(atleastOne,"select an organzation.");
        _;
    }

    modifier checkForList (
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress
    ){
        require(_initialPrice > 0 , "intial price can't be zero.");
        require(_tokenId >= 0 , "tokenid can't be negative.");
        require(_noOfCopies > 0 , "0 amount can't be listed.");
        require(_nftAddress != address(0), "Invalid address."); 
        
        if (_listStartTime != 0 && _listEndTime != 0 ){

            require(_listStartTime >= block.timestamp && _listEndTime > _listStartTime,
            "startTime and end time must be greater then currentTime");
        }
        _;        
    }
    
    modifier checkSell(uint256 _listId) {

        require(_listId > 0,"inavlid list id");
        require(listing[_listId].listed, "nft isnt listed yet.");
        require(!listing[_listId].nftClaimed,"Nft already sold");
        require(msg.sender != listing[_listId].nftOwner ,"nftOwner of this nft can not buy"); 
        _;
    }

    modifier checkFiscalSponsor(address _fiscalSponsor) {
        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _previousFiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);
        
        if(_haveSponsor){
            require(_fiscalSponsor == _previousFiscalSponser, "You are a malacious User.");
            // require(_fiscalSponsorPercentage != 0, "Your Fiscal Sponsor didnt set fee Yet!");
        }
        _;
    }


}

// 0x0000000000000000000000000000000000000000

// org1 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148
// org2 = 0x583031D1113aD414F02576BD6afaBfb302140225
// org3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB
// fiscl = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C
// 0xdDb68Efa4Fdc889cca414C0a7AcAd3C5Cc08A8C5

//  mint :0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8

