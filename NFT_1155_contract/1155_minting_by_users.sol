// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/security/Pausable.sol";


contract MyToken is ERC1155, Ownable,Pausable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => bool) public alreadyMinted;

    event Mints(address minter,uint256 tokenid,uint256 amount,string tokenUri);
    event BatchMints(address minter,uint256[] tokenid,uint256[] amount,string[] tokenUris);
    
    constructor(string memory _name, string memory _symbol) ERC1155("") {

        name = _name;
        symbol = _symbol;
    }

    function _setURI(uint256 _tokenId,string memory newuri) private    {
        _tokenURIs[_tokenId] = newuri;
    }
    

    function getTokenURI(uint256 _tokenId) public view returns (string memory) {

        string memory currentBaseURI = _tokenURIs[_tokenId];
        return string(abi.encodePacked(currentBaseURI));

    }

    function mint(/*uint256 _tokenId,*/ uint256 _amount,string memory _uri) external whenNotPaused {
        
        
        // require(_tokenId != 0, "TokenId cannot be 0");
        // require(!alreadyMinted[tokenId], "Tokens are already minted on this id.");
        require( _amount > 0 && _amount <= 100," NFT amount must be between 1 and 100");
        require(bytes(_uri).length > 0, "tokenuri cannot be empty");
        
        tokenId++;
        
        _mint(msg.sender, tokenId, _amount, "0x00");
        _setURI(tokenId, _uri);
        // alreadyMinted[_tokenId] = true;
        emit Mints(msg.sender, tokenId, _amount, _uri);

    }

    function mintBatch(/*uint256[] memory _tokenIds*/uint256 noOfTokens, uint256[] memory _amounts,string[] memory _tokenUris) external whenNotPaused {
        
        // require(_tokenIds.length > 0, "tokenId cannot be empty");
        require(_tokenUris.length > 0, "tokenUris cannot be empty"); // Remove this extar require statement
        require(_amounts.length > 0, "amounts cannot be empty"); // Remove this extar require statement
        require(_tokenUris.length == _amounts.length &&
                 _amounts.length == noOfTokens,"Array lengths must match");
        
        uint256 tokenid = ++tokenId;
        uint256[] memory ids;
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
                require(_amounts[i] > 0 && _amounts[i] <= 100,"Each NFT can have no more than 100 copies");
                ids[i]= tokenid;
                
                _setURI(tokenid, _tokenUris[i]);
                tokenid++;
        }
        
        _mintBatch(msg.sender, ids, _amounts, "0x00");

        emit BatchMints(msg.sender, ids, _amounts, _tokenUris);
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


}
