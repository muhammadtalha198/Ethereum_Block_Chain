// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface MintingContract{

  function fGetRoyaltyReceiver(uint256 _tokenid) external view returns(address reciver);
  function fgetRoyaltyFeeInPBP(uint256 _tokenId) external view returns (uint256 _royaltyfee);
}

contract Marketplace is Initializable, ERC1155HolderUpgradeable ,OwnableUpgradeable, UUPSUpgradeable ,  PausableUpgradeable {


    using SafeMathUpgradeable for uint256;

    MintingContract private mintingContract;

    address mintingContractAddress;
    
    address public MarketPlaceOwner;
    uint256 public serviceFeePercentage;

    uint256 public fixedPriceId;
    uint256 public auctionId;
 
    function initialize(address _mintingContract) initializer public {

        serviceFeePercentage = 250; 
        MarketPlaceOwner = msg.sender;
        mintingContractAddress = _mintingContract;
        mintingContract = MintingContract(_mintingContract);


        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    struct FixedPrice{

        bool isSold;
        bool listed;
        uint256 price;   
        uint256 tokenId;
        uint256 noOfCopies;
        address owner;
        address newOwner;
        address nftAddress;

    }

    struct DonationInfo{
        address organizationOne;
        address organizationTwo;
        address organizationThree;
        uint256 donatePercentage;
    }



    struct Auction{   

        bool isSold;
        bool listed;
        bool nftClaimed;
        uint256 tokenId;
        uint256 numberofcopies;
        uint256 initialPrice;
        uint256 auctionEndTime;      
        uint256 auctionStartTime;
        uint256 currentBidAmount;
        address nftOwner;
        address newOwner;
        address nftAddress;
        address currentBidder;
    }

    mapping (uint256 => Auction) public auction;
    mapping (uint256 => FixedPrice) public fixedPrice;
    mapping (uint256 => DonationInfo) public donationInfo;

    bool[] againstOne;

    mapping (address => bool) public isApproved;
   

    // function organisationApproval(address _organizationAddress) public  onlyOwner returns(bool){
    // //    isApproved[_organizationAddress] = choice;
    //    return true;
    // }
    
    
    // function setFiscalSponsor(uint256 _fiscalSponserFee, UserType choice ) external view {

    //     require(isApproved[msg.sender] == choice, "You are not a fiscal sponser of ");
        
    //     require(_fiscalSponserFee >= 500 && _fiscalSponserFee <= 10000,
    //         "donation percentage must be between 5 to 100");
 

    // }

    function listItemForFixedPrice(
        uint256 _tokenId,
        uint256 _noOfCopies, 
        uint256 _price,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage,
        address _fiscalSponser

    ) external  whenNotPaused OnlyTokenHolders (_tokenId , _nftAddress) returns(uint256) {

        // if(isFiscalSponsor[_fiscalSponser]){
        //     require(isFiscalSponsor[_fiscalSponser],"Please enter the right address of fiscal sponser.");
        // }
        

        require(_donatePercentage >= 500 && _donatePercentage <= 10000,
            "donation percentage must be between 5 to 100");
        
        require(_organizationOne != address(0) || _organizationTwo != address(0) 
            || _organizationThree != address(0), 
            "You must have to chose atleast one organization.");

        require(_tokenId >= 0,"No Negative number is allowed");
        require(_noOfCopies > 0,"nft amount can't be zero");
        require(_price > 0,"price can not be 0");
        require(_nftAddress != address(0),"Invalid NFT Address");

        fixedPriceId++;

        fixedPrice[fixedPriceId].owner = msg.sender;
        fixedPrice[fixedPriceId].listed = true;
        fixedPrice[fixedPriceId].price = _price;
        fixedPrice[fixedPriceId].tokenId = _tokenId;
        fixedPrice[fixedPriceId].noOfCopies = _noOfCopies;
        donationInfo[fixedPriceId].organizationOne = _organizationOne;
        donationInfo[fixedPriceId].organizationTwo = _organizationTwo;
        donationInfo[fixedPriceId].organizationThree = _organizationThree;
        donationInfo[fixedPriceId].donatePercentage = _donatePercentage;
        
        if(_nftAddress != mintingContractAddress)
        {
            fixedPrice[fixedPriceId].nftAddress = _nftAddress;
            IERC1155Upgradeable(mintingContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _noOfCopies,
                "0x00"
            );

        }else{

            fixedPrice[fixedPriceId].nftAddress = mintingContractAddress;
            IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _noOfCopies,
                "0x00"
            );
        }

        return fixedPriceId; 
    }

    //--List item for Auction--------------------------------------------------------------------/

    
    function listItemForAuction(
        uint256 _initialPrice,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime ,
        uint256 _tokenId,
        uint256 _numberofcopies,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage

    ) external   whenNotPaused OnlyTokenHolders(_tokenId , _nftAddress) returns(uint256){
        

        require(_donatePercentage >= 500 && _donatePercentage <= 10000,
            "donation percentage must be between 5 to 100");
        
        require(_organizationOne != address(0) || _organizationTwo != address(0) 
            || _organizationThree != address(0), 
            "You must have to chose atleast one organization.");

        require(_initialPrice > 0 , "intial price can't be zero.");
        require(_tokenId >= 0 , "tokenid can't be negative.");
        require(_numberofcopies > 0 , "0 amount can't be listed.");
        require(_nftAddress != address(0), "Invalid address.");
        require(_auctionStartTime >= block.timestamp && _auctionEndTime > block.timestamp ,
         "startTime and end time must be greater then currentTime");
        

        auctionId++;

        auction[auctionId].listed = true;
        auction[auctionId].tokenId = _tokenId;
        auction[auctionId].numberofcopies = _numberofcopies;
        auction[auctionId].initialPrice = _initialPrice;
        auction[auctionId].auctionStartTime = _auctionStartTime;
        auction[auctionId].auctionEndTime = _auctionEndTime;
        auction[auctionId].nftOwner = msg.sender;
        donationInfo[auctionId].organizationOne = _organizationOne;
        donationInfo[auctionId].organizationTwo = _organizationTwo;
        donationInfo[auctionId].organizationThree = _organizationThree;
        donationInfo[auctionId].donatePercentage = _donatePercentage;

        if(_nftAddress != mintingContractAddress)
        {
            auction[auctionId].nftAddress = _nftAddress;
            IERC1155Upgradeable(mintingContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId ,
                _numberofcopies,
                '0x00'
            );

        }else{

            auction[auctionId].nftAddress = mintingContractAddress;
            IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId ,
                _numberofcopies,
                '0x00'
            ); 

        }

         return auctionId;
    }

    // Buy Fixed Price---------------------------------------------------------------------------------------------------


    function BuyFixedPriceItem(uint256 _fixedId) payable external whenNotPaused { 

        require(_fixedId > 0,"inavlid auction id");
        require(msg.sender != fixedPrice[_fixedId].owner , "owner of this nft can not buy");    
        require(msg.value >=  fixedPrice[_fixedId].price,"send wrong amount in fifxed price");
        require(fixedPrice[fixedPriceId].listed, "nft isnt listed yet.");
        require(!fixedPrice[_fixedId].isSold, "Item is already Sold");

        fixedPrice[_fixedId].newOwner = msg.sender;
        uint256 serviceFee = calulatePlatFormServiceFee(fixedPrice[_fixedId].price, serviceFeePercentage);
        
        if(mintingContractAddress == fixedPrice[fixedPriceId].nftAddress){

            uint256 _royaltyPercentage = mintingContract.fgetRoyaltyFeeInPBP(
                fixedPrice[_fixedId].tokenId
            );
            address _royaltyReciver = mintingContract.fGetRoyaltyReceiver(
                fixedPrice[_fixedId].tokenId
            );

            uint256 royaltyFee = calculateRoyaltyFee(fixedPrice[_fixedId].price, _royaltyPercentage);
            uint256 totalFee = serviceFee + royaltyFee;
            uint256 amountSendToSeller = fixedPrice[_fixedId].price.sub(totalFee);        
        
            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(_royaltyReciver ,royaltyFee);
            transferFunds(fixedPrice[_fixedId].owner , amountSendToSeller);
        

        }else{

            uint256 amountSendToSeller = fixedPrice[_fixedId].price.sub(serviceFee);

            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(fixedPrice[_fixedId].owner , amountSendToSeller);

        }
       
        fixedPrice[_fixedId].isSold = true;

        IERC1155Upgradeable(fixedPrice[_fixedId].nftAddress).safeTransferFrom(
                address(this),
                fixedPrice[_fixedId].newOwner,
                fixedPrice[_fixedId].tokenId,
                fixedPrice[_fixedId].noOfCopies,
                '0x00'
            );
    }


    function startBid( uint256 _auctionId)  external payable whenNotPaused {

        require(_auctionId > 0,"inavlid auction id");
        require(block.timestamp > auction[_auctionId].auctionStartTime, "you canot bid before auction started.");
        require(msg.sender != auction[_auctionId].nftOwner,"Seller can not place the bid on his own NFT");
        require(msg.value >= auction[_auctionId].initialPrice, "place a higher Bid than initial price");
        require(auction[_auctionId].listed, "Nft must be listed before bidding");
        require(!auction[_auctionId].isSold, "Item is already Sold");


        address  currentBidder  = auction[_auctionId].currentBidder;

        uint256  currentBidAmount = auction[_auctionId].currentBidAmount;
        
        require(msg.value > currentBidAmount,"There is already higer or equal bid exist" );

        
        if(msg.value > currentBidAmount) {
            transferFunds(currentBidder ,currentBidAmount);
        }

        auction[_auctionId].currentBidder = msg.sender;
        auction[_auctionId].currentBidAmount = msg.value;

    }

    

    function auctionEnd(uint256 _auctionId) external {
        
        require(_auctionId > 0,"inavlid auction id");
        require(msg.sender == auction[_auctionId].nftOwner ,
                "Only the seller of NFT can end this auction");
        require(!auction[_auctionId].isSold,"You have already ended the auction");
        require(!auction[_auctionId].nftClaimed,"Higiest bidder already claimed the nft.");
        
        uint256 serviceFee = calulatePlatFormServiceFee(auction[_auctionId].initialPrice, serviceFeePercentage);

        if(mintingContractAddress == auction[_auctionId].nftAddress){

            address _royaltyReciver = mintingContract.fGetRoyaltyReceiver(
                auction[_auctionId].tokenId
            );
            uint256 _royaltyPercentage = mintingContract.fgetRoyaltyFeeInPBP(
                auction[_auctionId].tokenId
            );

            uint256 royaltyFee = calculateRoyaltyFee(auction[_auctionId].initialPrice, _royaltyPercentage);
            uint256 totalFee = serviceFee + royaltyFee;
            uint256 amountSendToSeller = auction[_auctionId].initialPrice.sub(totalFee);        
        
            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(_royaltyReciver ,royaltyFee);
            transferFunds(auction[_auctionId].nftOwner , amountSendToSeller);

        }else{

            uint256 amountSendToSeller = auction[_auctionId].initialPrice.sub(serviceFee);

            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(auction[_auctionId].nftOwner , amountSendToSeller);
        }

        auction[_auctionId].isSold = true;
        
        IERC1155Upgradeable(auction[_auctionId].nftAddress).safeTransferFrom(
                address(this),
                auction[_auctionId].currentBidder,
                auction[_auctionId].tokenId,
                auction[_auctionId].numberofcopies,
                '0x00'
        );
        

    }



    // Claim NFT

    function claimNFT(uint256 _auctionId) external {

        require(_auctionId > 0,"inavlid auction id");
        require(msg.sender == auction[_auctionId].currentBidder, "Only Higest Bidder can claim the NFT");
        require(!auction[_auctionId].nftClaimed,"Higiest bidder already claimed the nft.");
        
        if(!auction[_auctionId].isSold){
            require(block.timestamp > auction[_auctionId].auctionEndTime,"Canot claim nft auctiom time not ended!");
        } 
        else{
            revert("Auction Ended by the Seller and NFT Already tranfered to your wallet");
        }
    
        uint256 serviceFee = calulatePlatFormServiceFee(auction[_auctionId].initialPrice, serviceFeePercentage);

        if(mintingContractAddress == auction[_auctionId].nftAddress){

            address _royaltyReciver = mintingContract.fGetRoyaltyReceiver(
                auction[_auctionId].tokenId
            );
            uint256 _royaltyPercentage = mintingContract.fgetRoyaltyFeeInPBP(
                auction[_auctionId].tokenId
            );

            uint256 royaltyFee = calculateRoyaltyFee(auction[_auctionId].initialPrice, _royaltyPercentage);
            uint256 totalFee = serviceFee + royaltyFee;
            uint256 amountSendToSeller = auction[_auctionId].initialPrice.sub(totalFee);        
        
            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(_royaltyReciver ,royaltyFee);
            transferFunds(auction[_auctionId].nftOwner , amountSendToSeller);

        }else{

            uint256 amountSendToSeller = auction[_auctionId].initialPrice.sub(serviceFee);

            transferFunds(MarketPlaceOwner ,serviceFee);
            transferFunds(auction[_auctionId].nftOwner , amountSendToSeller);
        }

        auction[_auctionId].nftClaimed = true;
        
        IERC1155Upgradeable(auction[_auctionId].nftAddress).safeTransferFrom(
                address(this),
                auction[_auctionId].currentBidder,
                auction[_auctionId].tokenId,
                auction[_auctionId].numberofcopies,
                '0x00'
        );

                   
    }

    function cancellListingForFixedPRice(uint256 listingID) external {

        require(msg.sender == fixedPrice[listingID].owner , "You are not the owner");   
        require(fixedPrice[listingID].listed,"NFT is not liosted yet.");   
        require(!fixedPrice[listingID].isSold,"NFT is already sold , can not perform this action now");   

        IERC1155Upgradeable(fixedPrice[listingID].nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            fixedPrice[listingID].tokenId,
            fixedPrice[listingID].noOfCopies ,
            '0x00'
        );

        
            fixedPrice[listingID].listed = false;
            fixedPrice[listingID].price = 0;
            fixedPrice[listingID].tokenId = 0;
            fixedPrice[listingID].noOfCopies = 0;
            fixedPrice[listingID].nftAddress = address(0);
        
    }


    function cancellListingForAuction(uint256 listingID) external {

        require(msg.sender == auction[listingID].nftOwner , "You are not the owner");
        require(!auction[listingID].isSold,"NFT is alrady sold , can not perform this action now");
        require(!auction[listingID].nftClaimed,"NFT is alrady claimed,");
        
        IERC1155Upgradeable(auction[listingID].nftAddress).safeTransferFrom(
            address(this),
            auction[listingID].nftOwner,
            auction[listingID].tokenId,
            auction[listingID].numberofcopies,
            '0x00'
        );
                

        auction[listingID].listed = false;
        auction[listingID].tokenId = 0;
        auction[listingID].numberofcopies = 0;
        auction[listingID].initialPrice = 0;
        auction[listingID].auctionEndTime = 0;
        auction[listingID].auctionStartTime = 0;
        auction[listingID].nftAddress = address(0);
        auction[listingID].currentBidAmount = 0;
        auction[listingID].currentBidder = address(0);
        
    }


    function setPlatFormServiceFeePercentage(uint256 _serviceFeePercentage) external onlyOwner returns(uint256){
        require( _serviceFeePercentage >=100  && _serviceFeePercentage <= 1000, 
            "fee % must between in 1% to 10% ");

        serviceFeePercentage = _serviceFeePercentage;
        return serviceFeePercentage;
    }

    function calulatePlatFormServiceFee(uint256 _salePrice , uint256 _serviceFeePercentage) private pure returns(uint256){
        
        require(_salePrice !=0 , "Price of NFT can not be zero");
        require(_serviceFeePercentage !=0 , "_PBP can not be zero");
        
        uint256 serviceFee = _salePrice.mul(_serviceFeePercentage).div(10000);
        
        return serviceFee;
    }

     function calculateRoyaltyFee(uint256 _salePrice , uint256 _royaltyFeePercentage) private pure returns(uint256){

        require(_salePrice !=0 , "_salePrice can not be zero");
        require(_royaltyFeePercentage != 0 , "_PBP  can not zero");
        
        uint256 RoyaltyFee = _salePrice.mul(_royaltyFeePercentage).div(10000);
        
        return RoyaltyFee; 
    }

    function transferFunds(address _recipient, uint256 _amount) private {
        (bool success, ) = payable(_recipient).call{value: _amount}("");
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

    modifier OnlyTokenHolders(uint256 _tokenid , address _nftAddress){
        require(IERC1155Upgradeable(_nftAddress).balanceOf(msg.sender, _tokenid)>0 , "You are not the owner of Token");
        _;
    }


}
