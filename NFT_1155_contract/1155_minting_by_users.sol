// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract DRBSudi is ERC1155, Ownable, Pausable, ERC1155Burnable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;
    uint256 public mintingPrice;

    mapping(uint256 => string) private _tokenURIs;
    mapping(address => uint256[]) private userTokenIds;

    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);

    
    
    constructor(string memory _name, string memory _symbol, uint256 _mintingPrice) 
            ERC1155("") {

        name = _name;
        symbol = _symbol;
        mintingPrice = _mintingPrice;
    }

    

    function mint( uint256 _noOfCopies,string memory _uri) external payable whenNotPaused {
        
        require(bytes(_uri).length > 0, "tokenuri cannot be empty");
        
        if(msg.sender != owner()){
            require(msg.value == mintingPrice, "please put the right amount of price.");
        }
        
        _mint(msg.sender, tokenId, _noOfCopies, "0x00");
        _setURI(tokenId, _uri);
        userTokenIds[msg.sender].push(tokenId);
        
        tokenId++;
        
        emit Mints(msg.sender, tokenId, _noOfCopies, _uri);

    }



    function mintBatch(uint256 noOfTokens, uint256[] memory _noOfCopies,string[] memory _tokenUris) external payable whenNotPaused {
        
        require(_tokenUris.length > 0, "tokenUris cannot be empty"); 
        require(_noOfCopies.length > 0, "amounts cannot be empty"); 
        require(_tokenUris.length == _noOfCopies.length &&
                 _noOfCopies.length == noOfTokens,"Array lengths must match");
        
        if(msg.sender != owner()){
            require(msg.value == mintingPrice * noOfTokens, "please put the right amount of price.");
        }
        
        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
            
            tokenids[i]= tokenId;
            _setURI(tokenId, _tokenUris[i]);
            userTokenIds[msg.sender].push(tokenId);
            
            tokenId++;
        }

        _mintBatch(msg.sender, tokenids, _noOfCopies, "0x00");

        emit BatchMints(msg.sender, tokenids, _noOfCopies, _tokenUris);
    }

    function getUserTokenIds(address user) external view returns (uint256[] memory) {
        return userTokenIds[user];
    }

    function _setURI(uint256 _tokenId,string memory newuri) private {
        _tokenURIs[_tokenId] = newuri;
    }
    

    function uri(uint256 _tokenId) public view override returns (string memory) {

        string memory currentBaseURI = _tokenURIs[_tokenId];
        return string(abi.encodePacked(currentBaseURI));

    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setMintingPrice(uint256 _mintingPrice) external onlyOwner {
        mintingPrice = _mintingPrice;
    }

    function withdrawAmount() external onlyOwner {

        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
            require(success, "Withdrawal failure");
    }


}
