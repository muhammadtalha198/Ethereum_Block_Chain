// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract OwnaNft is ERC721, ERC721Burnable, Ownable, ERC721URIStorage {
    
    using Strings for uint256;

    // ============ Mutable Variables ============    
    uint256 public  noOfTokenId = 0;
    
    // ============ Events ============ 
    event minted(uint256 tokenId, string nftTitle, string uri, address Owna, address borrower);

    // ============ Struct ============
    struct Owna{
        string nftTitle;  
        address owner;  
        address borrower;
    }
   
    // ============ Mappings ============
    mapping (uint256 => Owna) public OwnaDetails;
    

    constructor() ERC721("NFT Loans", "PWNL") {}

    // ============ Functions ============
    function mint(address ownaContrat, address borrower, string memory nftTitle, string memory uri) public onlyOwner {

        require(bytes(uri).length > 0, "Invalid URI");
        require(ownaContrat != address(0), "Invalid ownaContrat address");
        require(borrower != address(0), "Invalid borrower address");
        require(bytes(nftTitle).length > 0, "Invalid NFT title");

        uint256 tokenId = ++noOfTokenId;
        _safeMint(ownaContrat, tokenId);
        _setTokenURI(tokenId, uri);
        
        OwnaDetails[tokenId].owner = ownaContrat;
        OwnaDetails[tokenId].borrower = borrower;
        OwnaDetails[tokenId].nftTitle = nftTitle;

        emit minted(tokenId, nftTitle, uri, ownaContrat, borrower );

    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    // burn the NFT from Different smart contract
    function burn(uint256 nftID) public override {
        require(_exists(nftID), "Invalid NFT ID");
    
        _burn(nftID);
        address addr = 0x0000000000000000000000000000000000000000;
        OwnaDetails[nftID].owner = addr;
        OwnaDetails[nftID].borrower = addr;
        OwnaDetails[nftID].nftTitle = "";
    }

    // tokenURI of the NFT
    function tokenURI(uint256 tokenId)public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function borrwerOf(uint256 tokenId) public view returns (address)
    {
        return OwnaDetails[tokenId].borrower ;
    }
}