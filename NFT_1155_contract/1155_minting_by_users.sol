// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/security/Pausable.sol";


contract MyToken is ERC1155, Ownable,Pausable {
    
    string public name;
    string public symbol;

    mapping(uint256 => string) private _tokenURIs;
    
    constructor(string memory _name, string memory _symbol) ERC1155("") {

        name = _name;
        symbol = _symbol;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _tokenURIs[tokenId] = uri;
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return _tokenURIs[tokenId];
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data,string memory uri) public onlyOwner {
        _mint(account, id, amount, data);
        setTokenURI(id, uri);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data,string[] memory uris) public onlyOwner{
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            setTokenURI(ids[i], uris[i]);
        }
    }

}
