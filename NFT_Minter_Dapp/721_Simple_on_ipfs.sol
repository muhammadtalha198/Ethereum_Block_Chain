


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyToken is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint => string) public tokenUri;

    constructor() ERC721("MyToken", "MTK") {}



    function safeMint(string memory _uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setURI(tokenId, _uri);
    }

    function _setURI(uint256 _tokenId,string memory newuri) private {
       tokenUri[_tokenId] = newuri;
    }

    function uri(uint256 _tokenId) public view  returns (string memory) {

        string memory currentBaseURI = tokenUri[_tokenId];
        return string(abi.encodePacked(currentBaseURI));
    }
}
