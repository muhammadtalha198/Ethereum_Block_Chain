

//SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.19;
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract collateral is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    event Transfered(address indexed sender, uint256 value);
    
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    
    
    function transferIntoTreasury() external payable whenNotPaused {
        
        require(msg.value > 0, "Invalid collateral Amount");
        emit Transfered( owner(), msg.value); 
    }
 


    function transferStorToUser(address  userAddress) external payable onlyOwner {
        
        require(msg.value > 0, "Invalid Amount");
        
        (bool success, ) = payable(userAddress).call{value: msg.value}("");
        require(success, "Withdrawal failure");
        
        emit Transfered( userAddress, msg.value);
    }

    function Treasury() external view returns(uint256){
        return address(this).balance;
    }

    function withdrawAmount(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "_amount must be less then Treasury.");
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdrawal failure");
    }

    receive() external payable {
        emit Transfered(msg.sender, msg.value);
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

}
