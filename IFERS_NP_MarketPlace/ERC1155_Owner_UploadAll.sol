/*

    In case owner is minting by him self then sale them 
    The ipfs link : https://ipfs.io/ipfs/QmTqdUbVkaNfie3YvJK4J7j2nErtMCkxwEfK7KzedFSpMs/{id}.json
    used to set in setUri function will be : https://ipfs.io/ipfs/QmTqdUbVkaNfie3YvJK4J7j2nErtMCkxwEfK7KzedFSpMs/

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract MyToken is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    
    string public name;
    string public symbol;
    uint256 public tokenId;
    uint256 public mintingPrice;

    mapping(address => uint256[]) private userTokenIds;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, uint256 _mintingPrice) initializer public {

        name = _name;
        symbol = _symbol;
        mintingPrice = _mintingPrice;

        __ERC1155_init("https://ipfs.io/ipfs/QmTqdUbVkaNfie3YvJK4J7j2nErtMCkxwEfK7KzedFSpMs/");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
    }

    function mint(uint256 amount) external payable  {

        if(msg.sender != owner()){
            require(msg.value == mintingPrice, "please put the right amount of price.");
        }
        
        tokenId++;
        _mint(msg.sender, tokenId, amount, "0x00");
        userTokenIds[msg.sender].push(tokenId);
    }

    function mintBatch(uint256 noOfTokens, uint256[] memory _noOfCopies) external payable {

        uint256[] memory tokenids = new uint256[](noOfTokens);
        
        for (uint256 i = 0; i < noOfTokens; i++) {
             
            tokenids[i]= tokenId;
            userTokenIds[msg.sender].push(tokenId);
            
            tokenId++;
        }

        _mintBatch(msg.sender, tokenids, _noOfCopies, "0x00");
    }
    
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function withdrawAmount() external onlyOwner {

        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
            require(success, "Withdrawal failure");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
