
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyToken is Initializable, ERC1155Upgradeable, ERC1155PausableUpgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, UUPSUpgradeable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;

    struct MinterInfo{
       
        string _tokenURIs;
        uint256 royaltyPercentage;
        address royaltyReceiver;
    }

    struct FiscalSponsor {
        
        bool approvedfee;
        bool haveFiscalSponsor;
        uint256 fiscalSponsorPercentage;
        address fiscalSponsor;
        address fiscalSponsorOf;

    }

    

    mapping (uint256 => MinterInfo) public minterInfo;
    mapping (address => FiscalSponsor) public fiscalSponsor;


    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);
    event SetRoyalityFee(address nftOwner,uint256 royaltyPercentage);
    event SetFiscalFee(address fiscalAddress, uint256 feePercentage);
    event ApproveFiscalFee(address fiscalAddress, bool _approved);
    

    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner,string memory _name, string memory _symbol) initializer public {

        name = _name;
        symbol = _symbol;

        __ERC1155_init("");
        __ERC1155Pausable_init();
        __Ownable_init(initialOwner);
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();
    }

     function mint( 
        uint256 _noOfCopies,
        string memory _uri, 
        uint256 _royaltyFeePercentage, 
        address _fiscalSponsor
        
        ) external whenNotPaused {

        
        require(bytes(_uri).length > 0, "tokenuri cannot be empty");
        require(_noOfCopies > 0, "_noOfCopies cannot be zero");
        require(_royaltyFeePercentage >= 100  && _royaltyFeePercentage <= 1000 , "_royaltyFeePercentage must be between 1 to 10");

        tokenId++;

        if(_fiscalSponsor != address(0)){
            fiscalSponsor[msg.sender].haveFiscalSponsor = true;
        }
        
        _mint(msg.sender, tokenId, _noOfCopies, "0x00");
        _setURI(tokenId, _uri);
       
        minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage;
        minterInfo[tokenId].royaltyReceiver = msg.sender;
        fiscalSponsor[msg.sender].fiscalSponsor = _fiscalSponsor;
        fiscalSponsor[msg.sender].fiscalSponsorOf = msg.sender;
        
        
        
        emit Mints(msg.sender, tokenId, _noOfCopies, _uri);
    }


    function mintBatch(
        uint256 noOfTokens, 
        uint256[] memory _noOfCopies,
        string[] memory _tokenUris,
        uint256[] memory _royaltyFeePercentage, 
        address _fiscalSponsor
    
    ) external whenNotPaused {
        
        require(_tokenUris.length > 0, "tokenUris cannot be empty"); 
        require(_noOfCopies.length > 0, "amounts cannot be empty"); 
        require(_tokenUris.length == _noOfCopies.length &&
                 _noOfCopies.length == noOfTokens,"Array lengths must match");

        if(_fiscalSponsor != address(0)){
            fiscalSponsor[msg.sender].haveFiscalSponsor = true;
        }
        
        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
            require(_royaltyFeePercentage[i] >= 100 && _royaltyFeePercentage[i] <= 1000 , 
                "_royaltyFeePercentage must be between 1 to 10");
            
            tokenId++;

            tokenids[i]= tokenId;
            _setURI(tokenId, _tokenUris[i]);

            minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage[i];
            minterInfo[tokenId].royaltyReceiver = msg.sender;
            
        }

        fiscalSponsor[msg.sender].fiscalSponsor = _fiscalSponsor;
        fiscalSponsor[msg.sender].fiscalSponsorOf = msg.sender;

        _mintBatch(msg.sender, tokenids, _noOfCopies, "0x00");

        emit BatchMints(msg.sender, tokenids, _noOfCopies, _tokenUris);
    }

    function setRoyalityPercentage(uint256 _tokenId, uint256 _royaltyFeePercentage) external {
       
        require(msg.sender == minterInfo[_tokenId].royaltyReceiver, "Only Nft owner can set royality fee." );
        require(_royaltyFeePercentage >= 100  && _royaltyFeePercentage <= 1000 , 
            "_royaltyFeePercentage must be between 1 to 10");

        minterInfo[_tokenId].royaltyPercentage = _royaltyFeePercentage;

        emit SetRoyalityFee(msg.sender, minterInfo[_tokenId].royaltyPercentage);
    }
    

    function _setURI(uint256 _tokenId,string memory newuri) private {
       minterInfo[_tokenId]._tokenURIs = newuri;
    }
    
    function uri(uint256 _tokenId) public view override returns (string memory) {

        string memory currentBaseURI = minterInfo[_tokenId]._tokenURIs;
        return string(abi.encodePacked(currentBaseURI));
    }


    function getMinterInfo(uint256 _tokenId) external view returns (uint256, address){
        
        return (
            minterInfo[_tokenId].royaltyPercentage,
            minterInfo[_tokenId].royaltyReceiver
        );
    }

    function getFiscalSponsor(address _organizationAddress) external view returns (uint256, address){
        
        return (
            fiscalSponsor[_organizationAddress].fiscalSponsorPercentage,
            fiscalSponsor[_organizationAddress].fiscalSponsor
        );
    }

    function setFiscalSponsorPercentage(address organizationAddress,uint256 _fiscalSponsorPercentage) external {
        
        require(fiscalSponsor[organizationAddress].haveFiscalSponsor,
            "No Fiscal sponsor aginst this organization.");
            
        require(_fiscalSponsorPercentage >= 100  && _fiscalSponsorPercentage <= 1000 , 
            "_fiscalSponsorPercentage must be between 1 to 10");
        
        require(msg.sender == fiscalSponsor[organizationAddress].fiscalSponsor,
            "Only fiscal sponser or the Organization can set and approve the fee.");

        fiscalSponsor[organizationAddress].fiscalSponsorPercentage = _fiscalSponsorPercentage;

        emit SetFiscalFee(msg.sender, _fiscalSponsorPercentage);
    }

    function approveFiscalSponsorPercentage(bool _approval) external {
        
        require(fiscalSponsor[msg.sender].haveFiscalSponsor,
            "No Fiscal sponsor against this organization.");
        
        require(msg.sender == fiscalSponsor[msg.sender].fiscalSponsorOf,
            "Only the Organization of this fiscal sponsor can approve this fee.");
        
        fiscalSponsor[msg.sender].approvedfee = _approval;
        fiscalSponsor[msg.sender].fiscalSponsorPercentage = 0;

        emit ApproveFiscalFee(msg.sender, _approval);
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

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155Upgradeable, ERC1155PausableUpgradeable)
    {
        super._update(from, to, ids, values);
    }
}


//0x17F6AD8Ef982297579C203069C1DbfFE4348c372 fiscal sponsor 
