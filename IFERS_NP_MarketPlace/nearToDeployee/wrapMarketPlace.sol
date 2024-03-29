

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

interface MintingContract{

    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address);
    function getFiscalSponsor(address _organizationAddress) external view returns (bool,uint256, address, address);
}

interface WMATIC {
    function balanceOf(address personAddress) external returns (uint256);
    function allowance(address proverAddress, address approvedAddress ) external returns (uint256);
    function approve(address guy, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract Marketplace is Initializable, ERC1155HolderUpgradeable ,OwnableUpgradeable, UUPSUpgradeable ,  PausableUpgradeable {

    using SafeMathUpgradeable for uint256;
    MintingContract public mintingContract;
    WMATIC public wMatic; 
    
    uint256 public listId;
    address public marketPlaceOwner;
    uint256 public serviceFeePercentage;
    address public mintingContractAddress;
    address public WrappedMaticAddress;

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
 
    function initialize(address _mintingContract,address _wrappedMaticAddress) initializer public {

        serviceFeePercentage = 250; 
        marketPlaceOwner = msg.sender;
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
        uint256 price;   
        uint256 tokenId;
        uint256 noOfCopies;
        address nftOwner;
        address nftAddress;
        uint256 listingEndTime;      
        uint256 listingStartTime;
        uint256 currentBidAmount;
        address currentBidder;
    }

    struct DonationInfo{

        uint256 noOfOrgazisations;
        uint256 donatePercentage;
        address organizationOne;
        address organizationTwo;
        address organizationThree;
    }


    mapping (uint256 => List) public listing;
    mapping (uint256 => DonationInfo) public donationInfo;



    //--List item for list--------------------------------------------------------------------/

     function listForUsers(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime,
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

        listItems( _initialPrice,_listStartTime,_listEndTime ,_tokenId,_noOfCopies,_nftAddress,_organizationOne,_organizationTwo,_organizationThree,_donatePercentage);
        return listId;

    }

   
    function listForOrganizations(
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime ,
        uint256 _tokenId,
        uint256 _noOfCopies,
        address _nftAddress,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree,
        uint256 _donatePercentage,
        address _fiscalSponsor
    ) external returns(uint256){

        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _previousFiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);
        
        if(_haveSponsor){
            require(_fiscalSponsor == _previousFiscalSponser, "You are a malacious User.");
            require(_fiscalSponsorPercentage != 0, "Your Fiscal Sponsor didnt set fee Yet!");
        }

        listItems( _initialPrice,_listStartTime,_listEndTime ,_tokenId,_noOfCopies,_nftAddress,_organizationOne,_organizationTwo,_organizationThree,_donatePercentage);
        return listId;

   }

    function listItems(
        
        uint256 _initialPrice,
        uint256 _listStartTime,
        uint256 _listEndTime ,
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
        // require(_listStartTime >= block.timestamp && _listEndTime > block.timestamp ,
        //  "startTime and end time must be greater then currentTime");

        require(_donatePercentage >= 500 && _donatePercentage <= 10000,
            "donation percentage must be between 5 to 100");


        listId++;

        listing[listId].listed = true;
        listing[listId].tokenId = _tokenId;
        listing[listId].noOfCopies = _noOfCopies;
        listing[listId].price = _initialPrice;
        listing[listId].listingStartTime = _listStartTime;
        listing[listId].listingEndTime = _listEndTime;
        listing[listId].nftOwner = msg.sender;
        

        if(_donatePercentage != 0){
            
           setDonationInfo(
                _donatePercentage, 
                listId, 
                _organizationOne, 
                _organizationTwo, 
                _organizationThree
            );

        }

        if(_nftAddress != mintingContractAddress){

            setMintingAddress( _tokenId, _noOfCopies,  listId,  _nftAddress);

        }else{

            setMintingAddress( _tokenId, _noOfCopies,  listId,  mintingContractAddress); 
        }

         return listId;
    }


    // Buy Fixed Price---------------------------------------------------------------------------------------------------
    function BuyFixedPriceItem(uint256 _listId) payable external whenNotPaused { 

        require(_listId > 0,"inavlid list id");
        
        require(listing[_listId].listed, 
            "nft isnt listed yet.");
        
        require(!listing[_listId].nftClaimed,
            "Nft already sold");
        
        require(msg.sender != listing[_listId].nftOwner ,
             "nftOwner of this nft can not buy");    
        
        require(msg.value >=  listing[_listId].price,
            "send wrong amount in fixed price");


        listing[_listId].currentBidder = msg.sender;
        
    


        // The  serviceFee is the platform fee which will goes to the Admin.
        uint256 serviceFee = calulateFee(listing[_listId].price, serviceFeePercentage);


        // The  donationFee is the fee which will goes to the non profitable Organizations.
        uint256 donationFee;
        
        if(donationInfo[_listId].noOfOrgazisations > 0){

           donationFee =  donationFeeTransfer(_listId, true);    
        }

        // The  fiscalFee is the fee which will goes to the Fiscal sponser of that non profitable Organizations.
        uint256 fiscalFee;
        
        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _fiscalSponser,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);

        if(_haveSponsor){
            
            fiscalFee = calulateFee(listing[_listId].price, _fiscalSponsorPercentage);
            transferFundsInEth(_fiscalSponser,fiscalFee);
        }

        // The  royaltyFee is the fee which will goes to First Owner of the Nft.
        uint256 royaltyFee;
        
        if(mintingContractAddress == listing[_listId].nftAddress){

            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(listing[_listId].tokenId);

            royaltyFee = calulateFee(listing[_listId].price, _royaltyPercentage);
            transferFundsInEth(_royaltyReciver ,royaltyFee);

        }


        uint256 amountSendToSeller = listing[_listId].price.sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));

            transferFundsInEth(marketPlaceOwner ,serviceFee);
            transferFundsInEth(listing[_listId].nftOwner , amountSendToSeller);

        
        
        listing[_listId].nftClaimed = true;
        
        if(listing[_listId].currentBidAmount != 0){

            transferFundsInEth(listing[_listId].currentBidder, listing[_listId].currentBidAmount);
        }


        transferNft(
            listing[_listId].nftAddress,
            address(this),
            listing[_listId].currentBidder, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        );


    }


    function startBid( uint256 _listId, uint256 _bidPrice)  external  whenNotPaused {

        require(_listId > 0,"inavlid list id");
        require(_bidPrice > 0,"inavlid _bidPrice");
        
        require(listing[_listId].listed,
            "Nft isn't listed!");
        require(!listing[_listId].nftClaimed,
            "Nft already sold");
        
        require(wMatic.balanceOf(msg.sender) >= _bidPrice, 
            "insufficent balance.");
        
        require(msg.sender != listing[_listId].nftOwner,
            "Seller can not place the bid.");
        
        require(block.timestamp > listing[_listId].listingStartTime,
            "you canot bid before list started.");

        uint256  currentBidAmount = listing[_listId].currentBidAmount;
        
        require(_bidPrice > currentBidAmount,
            "There is already higer or equal bid exist" );

        listing[_listId].currentBidder = msg.sender;
        listing[_listId].currentBidAmount = _bidPrice;

    }



    function acceptOffer(uint256 _listId) external whenNotPaused {

        require(_listId > 0,"inavlid list id");
        
        require(listing[_listId].listed,
             "Nft must be listed before bidding");
        
        require(!listing[_listId].nftClaimed,
            "Nft already sold");
        
        require(msg.sender == listing[_listId].nftOwner, 
            "Only nftOwner can accept the offer.");

        require(!listing[_listId].nftClaimed,
            "Already sold");
        
        require(listing[_listId].nftOwner == msg.sender,
            "only owner can accept.");

        
        // The  serviceFee is the platform fee which will goes to the Admin.
        uint256 serviceFee = calulateFee(listing[_listId].currentBidAmount, serviceFeePercentage);
        
        // The  donationFee is the fee which will goes to the non profitable Organizations.
        uint256 donationFee;

        if(donationInfo[_listId].noOfOrgazisations > 0){
           
            donationFee =  donationFeeTransfer(_listId, false);
        }

        // The  fiscalFee is the fee which will goes to the Fiscal sponser of that non profitable Organizations.
        uint256 fiscalFee;
        
        (
            bool _haveSponsor,
            uint256 _fiscalSponsorPercentage,
            address _fiscalSponsor,
        
        )  = mintingContract.getFiscalSponsor(msg.sender);

        if(_haveSponsor){
            
            fiscalFee = calulateFee(listing[_listId].currentBidAmount, _fiscalSponsorPercentage);

            transferFundsInWEth(listing[_listId].currentBidder, _fiscalSponsor,fiscalFee);
        }

        // The  royaltyFee is the fee which will goes to First Owner of the Nft.
        uint256 royaltyFee;
        
        if(mintingContractAddress == listing[_listId].nftAddress){

            (uint256 _royaltyPercentage,address _royaltyReciver) = mintingContract.getMinterInfo(listing[_listId].tokenId);

            royaltyFee = calulateFee(listing[_listId].currentBidAmount, _royaltyPercentage);
            transferFundsInWEth(listing[_listId].currentBidder,_royaltyReciver ,royaltyFee);

        }

        uint256 amountSendToSeller = listing[_listId].currentBidAmount.sub((((serviceFee.add(donationFee)).add(fiscalFee)).add(royaltyFee)));

            transferFundsInWEth(listing[_listId].currentBidder,marketPlaceOwner ,serviceFee);
            transferFundsInWEth(listing[_listId].currentBidder,listing[_listId].nftOwner , amountSendToSeller);


        listing[_listId].nftClaimed = true;


        transferNft(
            listing[_listId].nftAddress,
            address(this),
            listing[_listId].currentBidder, 
            listing[_listId].tokenId, 
            listing[_listId].noOfCopies
        );               
    }



    function cancellListingForlist(uint256 _listingID) external {

        require(msg.sender == listing[_listingID].nftOwner , "You are not the nftOwner");
        require(!listing[_listingID].nftClaimed,"NFT is alrady claimed,");
        
        transferNft(
            listing[_listingID].nftAddress,
            address(this),
            listing[_listingID].nftOwner, 
            listing[_listingID].tokenId, 
            listing[_listingID].noOfCopies
        );
                

        listing[_listingID].listed = false;
        listing[_listingID].tokenId = 0;
        listing[_listingID].noOfCopies = 0;
        listing[_listingID].price = 0;
        listing[_listingID].listingEndTime = 0;
        listing[_listingID].listingStartTime = 0;
        listing[_listingID].nftAddress = address(0);
        listing[_listingID].currentBidAmount = 0;
        listing[_listingID].currentBidder = address(0);
        
    }

    function setDonationInfo(

        uint256 _donatePercentage,
        uint256 _priceId,
        address _organizationOne,
        address _organizationTwo,
        address _organizationThree

        ) private {

            donationInfo[_priceId].donatePercentage = _donatePercentage;
            
            if(_organizationOne != address(0)){
                donationInfo[_priceId].organizationOne = _organizationOne;
                donationInfo[_priceId].noOfOrgazisations += 1;
            }
            
            if(_organizationTwo != address(0)){
                donationInfo[_priceId].organizationTwo = _organizationTwo;
                donationInfo[_priceId].noOfOrgazisations += 1;
            }
            
            if(_organizationThree != address(0)){
                donationInfo[_priceId].organizationThree = _organizationThree;
                donationInfo[_priceId].noOfOrgazisations += 1;
            }
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

         IERC1155Upgradeable(_nftAddress).safeTransferFrom(
                _from,
                _to,
                _tokenId,
                _noOfcopies,
                '0x00'
            );

    }


    function donationFeeTransfer(uint256 _id , bool _inEth) private returns (uint256){

        uint256 _donationFee = calulateFee(listing[_id].price, donationInfo[_id].donatePercentage);
       
       
        if(donationInfo[_id].noOfOrgazisations == 1){
            
            if(donationInfo[_id].organizationOne == address(0) && donationInfo[_id].organizationTwo == address(0) ){
                if(_inEth){
                    transferFundsInEth(donationInfo[_id].organizationThree ,_donationFee);
                }else{
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationThree ,_donationFee);
                }

            } else if (donationInfo[_id].organizationOne == address(0) && donationInfo[_id].organizationThree == address(0)){
                if(_inEth){
                    transferFundsInEth(donationInfo[_id].organizationTwo ,_donationFee); 
                }else{
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationTwo ,_donationFee); 
                }

            } else{
                
                if(_inEth){
                    transferFundsInEth(donationInfo[_id].organizationOne ,_donationFee);

                }else{
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationOne ,_donationFee);
                }
            }

        } else if (donationInfo[_id].noOfOrgazisations == 2){

            uint256 perUserFee = _donationFee.div(donationInfo[_id].noOfOrgazisations);
            
            if(donationInfo[_id].organizationOne == address(0)){
                
                if(_inEth){

                    transferFundsInEth(donationInfo[_id].organizationTwo ,perUserFee);
                    transferFundsInEth(donationInfo[_id].organizationThree ,perUserFee);

                }else{

                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationTwo ,perUserFee);
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationThree ,perUserFee);
                }

            } else if (donationInfo[_id].organizationTwo == address(0)){
                if(_inEth){

                    transferFundsInEth(donationInfo[_id].organizationOne ,perUserFee);
                    transferFundsInEth(donationInfo[_id].organizationThree ,perUserFee);
                }else{

                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationOne ,perUserFee);
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationThree ,perUserFee);
                }

            }else{
                if(_inEth){

                    transferFundsInEth(donationInfo[_id].organizationOne ,perUserFee);
                    transferFundsInEth(donationInfo[_id].organizationTwo ,perUserFee);
                }else{

                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationOne ,perUserFee);
                    transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationTwo ,perUserFee);
                }
            }

        } else {


            uint256 perUserFee = _donationFee.div(donationInfo[_id].noOfOrgazisations);

            
            if(_inEth){



                transferFundsInEth(donationInfo[_id].organizationOne ,perUserFee);
                transferFundsInEth(donationInfo[_id].organizationTwo ,perUserFee);
                transferFundsInEth(donationInfo[_id].organizationThree ,perUserFee);

            }else{
                transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationOne ,perUserFee);
                transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationTwo ,perUserFee);
                transferFundsInWEth(listing[_id].currentBidder, donationInfo[_id].organizationThree ,perUserFee);

                }

        }

        return _donationFee;
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



    function transferFundsInEth(address _recipient, uint256 _amount) private {
        // (bool success, ) = payable(_recipient).call{value: _amount}("");

        console.log("_recipient",_recipient);
        console.log("_amount",_amount);

         payable(_recipient).transfer(_amount);

        console.log("_recipient",_recipient);
        console.log("_amount",_amount);
        // require(success, "Transfer  fee failed");
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

    modifier OnlyTokenHolders(uint256 _tokenid , address _nftAddress){
        require(IERC1155Upgradeable(_nftAddress).balanceOf(msg.sender, _tokenid)>0 , "You are not the nftOwner of Token");
        _;
    }


}



// 0x0000000000000000000000000000000000000000

// nft + 0xf8e81D47203A594245E36C48e151709F0C19fBe8 
