

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";



interface MintingContract{

    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address);
    function getFiscalSponsor(address _organizationAddress) external view returns (uint256, address);
}

contract Marketplace is Initializable, ERC1155HolderUpgradeable ,OwnableUpgradeable, UUPSUpgradeable ,  PausableUpgradeable {

    using SafeMathUpgradeable for uint256;
    MintingContract private mintingContract;

    
    uint256 public auctionId;
    uint256 public fixedPriceId;
    address public marketPlaceOwner;
    uint256 public serviceFeePercentage;
    address public mintingContractAddress;

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
 
    function initialize(address _mintingContract) initializer public {

        serviceFeePercentage = 250; 
        marketPlaceOwner = msg.sender;
        mintingContractAddress = _mintingContract;
        mintingContract = MintingContract(_mintingContract);


        __Pausable_init();
        __ERC1155Holder_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
       
    }

    struct FixedPrice{

        bool isSold;
        bool listed;
        uint256 price;   
        uint256 tokenId;
        uint256 noOfCopies;
        address nftOwner;
        address newOwner;
        address nftAddress;

    }

    struct Auction{   

        bool isSold;
        bool listed;
        bool nftClaimed;
        uint256 tokenId;
        uint256 noOfCopies;
        uint256 initialPrice;
        uint256 auctionEndTime;      
        uint256 auctionStartTime;
        uint256 currentBidAmount;
        address nftOwner;
        address newOwner;
        address nftAddress;
        address currentBidder;
    }

    struct DonationInfo{
        uint256 noOfOrgazisations;
        uint256 donatePercentage;
        address organizationOne;
        address organizationTwo;
        address organizationThree;
    }


    mapping (uint256 => Auction) public auction;
    mapping (uint256 => FixedPrice) public fixedPrice;
    mapping (uint256 => DonationInfo) public donationInfoFixed;
    mapping (uint256 => DonationInfo) public donationInfoAuction;

   function fixedForUser(
        uint256 _tokenId,
        uint256 _noOfCopies, 
        uint256 _price,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage
   ) external returns(uint256){

        require(_organizationOne != address(0) || _organizationTwo != address(0) 
                || _organizationThree != address(0), 
                "You must have to chose atleast one organization.");

        listItemForFixedPrice( _tokenId, _noOfCopies,  _price, _nftAddress, _organizationOne, _organizationTwo, _organizationThree, _donatePercentage);
        return fixedPriceId;
   }

    function fixedForOrganizations(
        uint256 _tokenId,
        uint256 _noOfCopies, 
        uint256 _price,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage
    ) external returns(uint256){

        listItemForFixedPrice( _tokenId, _noOfCopies,  _price, _nftAddress, _organizationOne, _organizationTwo, _organizationThree, _donatePercentage);
        return fixedPriceId;

   }
   

    
    

    function listItemForFixedPrice(
        uint256 _tokenId,
        uint256 _noOfCopies, 
        uint256 _price,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage
    ) private  whenNotPaused OnlyTokenHolders (_tokenId , _nftAddress) {

        require(_tokenId >= 0,"No Negative number is allowed");
        require(_noOfCopies > 0,"nft amount can't be zero");
        require(_price > 0,"price can not be 0");
        require(_nftAddress != address(0),"Invalid NFT Address");
        
        require(_donatePercentage >= 500 && _donatePercentage <= 10000,
            "donation percentage must be between 5 to 100");
        

        fixedPriceId++;

        fixedPrice[fixedPriceId].nftOwner = msg.sender;
        fixedPrice[fixedPriceId].listed = true;
        fixedPrice[fixedPriceId].price = _price;
        fixedPrice[fixedPriceId].tokenId = _tokenId;
        fixedPrice[fixedPriceId].noOfCopies = _noOfCopies;
        
        if(_donatePercentage != 0){
            
            donationInfoFixed[fixedPriceId].donatePercentage = _donatePercentage;
            
            if(_organizationOne != address(0)){
                donationInfoFixed[fixedPriceId].organizationOne = _organizationOne;
                donationInfoFixed[fixedPriceId].noOfOrgazisations += 1;
            }
            
            if(_organizationTwo != address(0)){
                donationInfoFixed[fixedPriceId].organizationTwo = _organizationTwo;
                donationInfoFixed[fixedPriceId].noOfOrgazisations += 1;
            }
            
            if(_organizationThree != address(0)){
                donationInfoFixed[fixedPriceId].organizationThree = _organizationThree;
                donationInfoFixed[fixedPriceId].noOfOrgazisations += 1;
            }

        }
        
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
 
    }

    function BuyFixedPriceItem(uint256 _fixedId) payable external whenNotPaused { 

        require(_fixedId > 0,"inavlid auction id");
        require(msg.sender != fixedPrice[_fixedId].nftOwner , "nftOwner of this nft can not buy");    
        require(msg.value >=  fixedPrice[_fixedId].price,"send wrong amount in fixed price");
        require(fixedPrice[fixedPriceId].listed, "nft isnt listed yet.");
        require(!fixedPrice[_fixedId].isSold, "Item is already Sold");

        fixedPrice[_fixedId].newOwner = msg.sender;
        
        // The  serviceFee is the platform fee which will goes to the Admin.
        uint256 serviceFee = calulateFee(fixedPrice[_fixedId].price, serviceFeePercentage);

        // The  donationFee is the fee which will goes to the non profitable Organizations.
        uint256 donationFee;

        if(donationInfoFixed[_fixedId].noOfOrgazisations > 0){

            
            donationFee = calulateFee(fixedPrice[_fixedId].price, donationInfoFixed[_fixedId].donatePercentage);
           
            if(donationInfoFixed[_fixedId].noOfOrgazisations == 1){
                
                if(donationInfoFixed[_fixedId].organizationOne == address(0) && donationInfoFixed[_fixedId].organizationTwo == address(0) ){

                    transferFunds(donationInfoFixed[_fixedId].organizationThree ,serviceFee);

                } else if (donationInfoFixed[_fixedId].organizationOne == address(0) && donationInfoFixed[_fixedId].organizationThree == address(0)){

                    transferFunds(donationInfoFixed[_fixedId].organizationTwo ,serviceFee); 

                } else{

                       transferFunds(donationInfoFixed[_fixedId].organizationOne ,serviceFee);
                }

            } else if (donationInfoFixed[_fixedId].noOfOrgazisations == 2){

                uint256 perUserFee = donationFee.div(donationInfoFixed[_fixedId].noOfOrgazisations);
                
                if(donationInfoFixed[_fixedId].organizationOne == address(0)){

                    transferFunds(donationInfoFixed[_fixedId].organizationTwo ,perUserFee);
                    transferFunds(donationInfoFixed[_fixedId].organizationThree ,perUserFee);

                } else if (donationInfoFixed[_fixedId].organizationTwo == address(0)){

                    transferFunds(donationInfoFixed[_fixedId].organizationOne ,perUserFee);
                    transferFunds(donationInfoFixed[_fixedId].organizationThree ,perUserFee);

                }else{

                    transferFunds(donationInfoFixed[_fixedId].organizationOne ,perUserFee);
                    transferFunds(donationInfoFixed[_fixedId].organizationTwo ,perUserFee);
                }

            } else {

                uint256 perUserFee = donationFee.div(donationInfoFixed[_fixedId].noOfOrgazisations);

                transferFunds(donationInfoFixed[_fixedId].organizationOne ,perUserFee);
                transferFunds(donationInfoFixed[_fixedId].organizationTwo ,perUserFee);
                transferFunds(donationInfoFixed[_fixedId].organizationThree ,perUserFee);

            }
        }

        // The  fiscalFee is the fee which will goes to the Fiscal sponser of that non profitable Organizations.
        uint256 fiscalFee;
        
        (uint256 _fiscalSponsorPercentage,address _fiscalSponser) = mintingContract.getFiscalSponsor(fixedPrice[_fixedId].nftOwner);

        if(_fiscalSponser != address(0)){
            
            fiscalFee = calulateFee(fixedPrice[_fixedId].price, _fiscalSponsorPercentage);

            transferFunds(_fiscalSponser,fiscalFee);
        }

        // The  royaltyFee is the fee which will goes to First Owner of the Nft.
        uint256 royaltyFee;
        
        if(mintingContractAddress == fixedPrice[fixedPriceId].nftAddress){

            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(fixedPrice[_fixedId].tokenId);

            royaltyFee = calulateFee(fixedPrice[_fixedId].price, _royaltyPercentage);
            transferFunds(_royaltyReciver ,royaltyFee);

        }



        uint256 amountSendToSeller = fixedPrice[_fixedId].price.sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));

            transferFunds(marketPlaceOwner ,serviceFee);
            transferFunds(fixedPrice[_fixedId].nftOwner , amountSendToSeller);

       
        fixedPrice[_fixedId].isSold = true;

        IERC1155Upgradeable(fixedPrice[_fixedId].nftAddress).safeTransferFrom(
                address(this),
                fixedPrice[_fixedId].newOwner,
                fixedPrice[_fixedId].tokenId,
                fixedPrice[_fixedId].noOfCopies,
                '0x00'
            );
    }

    function cancellListingForFixedPRice(uint256 listingID) external {

        require(msg.sender == fixedPrice[listingID].nftOwner , "You are not the nftOwner");   
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





    //--List item for Auction--------------------------------------------------------------------/

     function auctionForUsers(
         uint256 _initialPrice,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage
    ) external returns(uint256){

        require(_organizationOne != address(0) || _organizationTwo != address(0) 
                || _organizationThree != address(0), 
                "You must have to chose atleast one organization.");

        listItemForAuction( _initialPrice,_auctionStartTime,_auctionEndTime ,_tokenId,_noOfCopies,_nftAddress,_organizationOne,_organizationTwo,_organizationThree,_donatePercentage);
        return auctionId;

    }

   
    function auctionForOrganizations(
        uint256 _initialPrice,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage
    ) external returns(uint256){

        listItemForAuction( _initialPrice,_auctionStartTime,_auctionEndTime ,_tokenId,_noOfCopies,_nftAddress,_organizationOne,_organizationTwo,_organizationThree,_donatePercentage);
        return auctionId;

   }


    
    function listItemForAuction(
        uint256 _initialPrice,
        uint256 _auctionStartTime,
        uint256 _auctionEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage

    ) private  whenNotPaused OnlyTokenHolders(_tokenId , _nftAddress) returns(uint256){
        
        require(_initialPrice > 0 , "intial price can't be zero.");
        require(_tokenId >= 0 , "tokenid can't be negative.");
        require(_noOfCopies > 0 , "0 amount can't be listed.");
        require(_nftAddress != address(0), "Invalid address.");
        require(_auctionStartTime >= block.timestamp && _auctionEndTime > block.timestamp ,
         "startTime and end time must be greater then currentTime");

        require(_donatePercentage >= 500 && _donatePercentage <= 10000,
            "donation percentage must be between 5 to 100");

        

        auctionId++;

        auction[auctionId].listed = true;
        auction[auctionId].tokenId = _tokenId;
        auction[auctionId].noOfCopies = _noOfCopies;
        auction[auctionId].initialPrice = _initialPrice;
        auction[auctionId].auctionStartTime = _auctionStartTime;
        auction[auctionId].auctionEndTime = _auctionEndTime;
        auction[auctionId].nftOwner = msg.sender;
        
        

        if(_donatePercentage != 0){
            
            donationInfoAuction[auctionId].donatePercentage = _donatePercentage;
            
            if(_organizationOne != address(0)){
                donationInfoAuction[auctionId].organizationOne = _organizationOne;
                donationInfoAuction[auctionId].noOfOrgazisations += 1;
            }
            
            if(_organizationTwo != address(0)){
                donationInfoAuction[auctionId].organizationTwo = _organizationTwo;
                donationInfoAuction[auctionId].noOfOrgazisations += 1;
            }
            
            if(_organizationThree != address(0)){
                donationInfoAuction[auctionId].organizationThree = _organizationThree;
                donationInfoAuction[auctionId].noOfOrgazisations += 1;
            }

        }

        if(_nftAddress != mintingContractAddress)
        {
            auction[auctionId].nftAddress = _nftAddress;
            IERC1155Upgradeable(mintingContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId ,
                _noOfCopies,
                '0x00'
            );

        }else{

            auction[auctionId].nftAddress = mintingContractAddress;
            IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId ,
                _noOfCopies,
                '0x00'
            ); 

        }

         return auctionId;
    }

    // Buy Fixed Price---------------------------------------------------------------------------------------------------


    


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

        auction[_auctionId].newOwner = msg.sender;
        auction[_auctionId].currentBidAmount = msg.value;

    }

    // Claim NFT

    function claimNFT(uint256 _auctionId) external {

        require(_auctionId > 0,"inavlid auction id");
        require(msg.sender == auction[_auctionId].newOwner, "Only Higest Bidder can claim the NFT");
        require(!auction[_auctionId].nftClaimed,"Higiest bidder already claimed the nft.");
        
          auction[_auctionId].newOwner = msg.sender;
        
        // The  serviceFee is the platform fee which will goes to the Admin.
        uint256 serviceFee = calulateFee(auction[_auctionId].currentBidAmount, serviceFeePercentage);
        
        // The  donationFee is the fee which will goes to the non profitable Organizations.
        uint256 donationFee;

        if(donationInfoAuction[_auctionId].noOfOrgazisations > 0){

            
            donationFee = calulateFee(auction[_auctionId].currentBidAmount, donationInfoAuction[_auctionId].donatePercentage);
           
            if(donationInfoAuction[_auctionId].noOfOrgazisations == 1){
                
                if(donationInfoAuction[_auctionId].organizationOne == address(0) && donationInfoAuction[_auctionId].organizationTwo == address(0) ){

                    transferFunds(donationInfoAuction[_auctionId].organizationThree ,serviceFee);

                } else if (donationInfoAuction[_auctionId].organizationOne == address(0) && donationInfoAuction[_auctionId].organizationThree == address(0)){

                    transferFunds(donationInfoAuction[_auctionId].organizationTwo ,serviceFee); 

                } else{

                       transferFunds(donationInfoAuction[_auctionId].organizationOne ,serviceFee);
                }

            } else if (donationInfoAuction[_auctionId].noOfOrgazisations == 2){

                uint256 perUserFee = donationFee.div(donationInfoAuction[_auctionId].noOfOrgazisations);
                
                if(donationInfoAuction[_auctionId].organizationOne == address(0)){

                    transferFunds(donationInfoAuction[_auctionId].organizationTwo ,perUserFee);
                    transferFunds(donationInfoAuction[_auctionId].organizationThree ,perUserFee);

                } else if (donationInfoAuction[_auctionId].organizationTwo == address(0)){

                    transferFunds(donationInfoAuction[_auctionId].organizationOne ,perUserFee);
                    transferFunds(donationInfoAuction[_auctionId].organizationThree ,perUserFee);

                }else{

                    transferFunds(donationInfoAuction[_auctionId].organizationOne ,perUserFee);
                    transferFunds(donationInfoAuction[_auctionId].organizationTwo ,perUserFee);
                }

            } else {

                uint256 perUserFee = donationFee.div(donationInfoAuction[_auctionId].noOfOrgazisations);

                transferFunds(donationInfoAuction[_auctionId].organizationOne ,perUserFee);
                transferFunds(donationInfoAuction[_auctionId].organizationTwo ,perUserFee);
                transferFunds(donationInfoAuction[_auctionId].organizationThree ,perUserFee);

            }
        }

        // The  fiscalFee is the fee which will goes to the Fiscal sponser of that non profitable Organizations.
        uint256 fiscalFee;
        
        (uint256 _fiscalSponsorPercentage,address _fiscalSponser) = mintingContract.getFiscalSponsor(auction[_auctionId].nftOwner);

        if(_fiscalSponser != address(0)){
            
            fiscalFee = calulateFee(auction[_auctionId].currentBidAmount, _fiscalSponsorPercentage);

            transferFunds(_fiscalSponser,fiscalFee);
        }

        // The  royaltyFee is the fee which will goes to First Owner of the Nft.
        uint256 royaltyFee;
        
        if(mintingContractAddress == auction[fixedPriceId].nftAddress){

            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(auction[_auctionId].tokenId);

            royaltyFee = calulateFee(auction[_auctionId].currentBidAmount, _royaltyPercentage);
            transferFunds(_royaltyReciver ,royaltyFee);

        }



        uint256 amountSendToSeller = auction[_auctionId].currentBidAmount.sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));

            transferFunds(marketPlaceOwner ,serviceFee);
            transferFunds(auction[_auctionId].nftOwner , amountSendToSeller);


        auction[_auctionId].nftClaimed = true;
        
        IERC1155Upgradeable(auction[_auctionId].nftAddress).safeTransferFrom(
                address(this),
                auction[_auctionId].newOwner,
                auction[_auctionId].tokenId,
                auction[_auctionId].noOfCopies,
                '0x00'
        );

                   
    }


    function cancellListingForAuction(uint256 listingID) external {

        require(msg.sender == auction[listingID].nftOwner , "You are not the nftOwner");
        require(!auction[listingID].isSold,"NFT is alrady sold , can not perform this action now");
        require(!auction[listingID].nftClaimed,"NFT is alrady claimed,");
        
        IERC1155Upgradeable(auction[listingID].nftAddress).safeTransferFrom(
            address(this),
            auction[listingID].nftOwner,
            auction[listingID].tokenId,
            auction[listingID].noOfCopies,
            '0x00'
        );
                

        auction[listingID].listed = false;
        auction[listingID].tokenId = 0;
        auction[listingID].noOfCopies = 0;
        auction[listingID].initialPrice = 0;
        auction[listingID].auctionEndTime = 0;
        auction[listingID].auctionStartTime = 0;
        auction[listingID].nftAddress = address(0);
        auction[listingID].currentBidAmount = 0;
        auction[listingID].newOwner = address(0);
        
    }


    function setPlatFormServiceFeePercentage(uint256 _serviceFeePercentage) external onlyOwner returns(uint256){
        require( _serviceFeePercentage >=100  && _serviceFeePercentage <= 1000, 
            "fee % must between in 1% to 10% ");

        serviceFeePercentage = _serviceFeePercentage;
        return serviceFeePercentage;
    }

    function calulateFee(uint256 _salePrice , uint256 _serviceFeePercentage) private pure returns(uint256){
        
        require(_salePrice !=0 , "Price of NFT can not be zero");
        require(_serviceFeePercentage !=0 , "_PBP can not be zero");
        
        uint256 serviceFee = _salePrice.mul(_serviceFeePercentage).div(10000);
        
        return serviceFee;
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
        require(IERC1155Upgradeable(_nftAddress).balanceOf(msg.sender, _tokenid)>0 , "You are not the nftOwner of Token");
        _;
    }


}