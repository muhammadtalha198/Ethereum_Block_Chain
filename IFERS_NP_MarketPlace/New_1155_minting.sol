
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.0.0/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.0.0/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@5.0.0/proxy/utils/UUPSUpgradeable.sol";

contract MyToken is Initializable, ERC1155Upgradeable, ERC1155PausableUpgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, UUPSUpgradeable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;

    struct MinterInfo{
        string _tokenURIs;
        uint256 royaltyPercentage;
        address royaltyReceiver;
    }

    mapping (uint256 => MinterInfo) public minterInfo;
    mapping(address => uint256[]) private userTokenIds;

    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);
    event SetRoyalityFee(address nftOwner,uint256 royaltyPercentage);
    

    
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

     function mint(uint256 _noOfCopies,string memory _uri, uint256 _royaltyFeePercentage) 
        external
        whenNotPaused {
        
        require(bytes(_uri).length > 0, "tokenuri cannot be empty");
        require(_noOfCopies > 0, "_noOfCopies cannot be zero");
        require(_royaltyFeePercentage >= 100  && _royaltyFeePercentage <= 1000 , "_royaltyFeePercentage must be between 1 to 10");

        tokenId++;
        
        _mint(msg.sender, tokenId, _noOfCopies, "0x00");
        _setURI(tokenId, _uri);
        userTokenIds[msg.sender].push(tokenId);

        minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage;
        minterInfo[tokenId].royaltyReceiver = msg.sender;
        
        
        emit Mints(msg.sender, tokenId, _noOfCopies, _uri);
    }


    function mintBatch(uint256 noOfTokens, uint256[] memory _noOfCopies,string[] memory _tokenUris,uint256[] memory _royaltyFeePercentage) 
        external
        whenNotPaused {
        
        require(_tokenUris.length > 0, "tokenUris cannot be empty"); 
        require(_noOfCopies.length > 0, "amounts cannot be empty"); 
        require(_tokenUris.length == _noOfCopies.length &&
                 _noOfCopies.length == noOfTokens,"Array lengths must match");
        
        
        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
            require(_royaltyFeePercentage[i] >= 100 && _royaltyFeePercentage[i] <= 1000 , 
                "_royaltyFeePercentage must be between 1 to 10");
            
            tokenId++;

            tokenids[i]= tokenId;
            _setURI(tokenId, _tokenUris[i]);
            userTokenIds[msg.sender].push(tokenId);

            minterInfo[tokenId].royaltyPercentage = _royaltyFeePercentage[i];
            minterInfo[tokenId].royaltyReceiver = msg.sender;
            
        }

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

    function getUserTokenIds(address user) external view returns (uint256[] memory) {
        return userTokenIds[user];
    }

    function getRoyaltyFeepercentage(uint256 _tokenId) external view returns (uint256 _royaltyfee)
    {
        return minterInfo[_tokenId].royaltyPercentage;
    }

    function getetRoyaltyReceiver(uint256 _tokenid) external view returns(address reciver)
    {
        return minterInfo[_tokenid].royaltyReceiver;
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
