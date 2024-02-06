// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "hardhat/console.sol";

contract ReferralSystem {
   
    struct ReferalInfo{
        bool hasReferal;
        address ownerOf;
    }

    struct OwnerInfo{
        uint256[] levelNo;
        address[] ownerIs;
    }

    mapping(address  => OwnerInfo)  ownerInfo;
    mapping(address => ReferalInfo) public referalInfo;


    function UserRegister( address referalAddress) external   {
        require(msg.sender != address(0), "Invalid msg.sender address");
        require(referalAddress != address(0), "Invalid referral person address");

       referalInfo[msg.sender].hasReferal = true;
       referalInfo[msg.sender].ownerOf = referalAddress;
    

        if (referalInfo[msg.sender].hasReferal) {
            
            if(!referalInfo[referalAddress].hasReferal){
                ownerInfo[referalAddress].levelNo.push(1);
                ownerInfo[referalAddress].ownerIs.push(msg.sender);
            }
            else{
                    _updateChainOfOwnership(msg.sender,referalAddress,1);
            }
        }
    }


    // Internal function to update the chain of ownership recursively
    function _updateChainOfOwnership(address originalOwner, address _referalAddress,uint256 level) private {
       
        ownerInfo[_referalAddress].ownerIs.push(originalOwner);  
        ownerInfo[_referalAddress].levelNo.push(level);
        address previousReferal = referalInfo[_referalAddress].ownerOf;
        if (previousReferal != address(0)) {
            _updateChainOfOwnership(originalOwner, previousReferal, level + 1);
        
        }
    }

    // Getter function to retrieve level numbers and owners for a given address
    function getOwnInfo(address _owner) external view returns (uint256[] memory, address[] memory) {
        return (ownerInfo[_owner].levelNo, ownerInfo[_owner].ownerIs);
    }
}


// 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
// 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
// 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
// 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
// 0x617F2E2fD72FD9D5503197092aC168c91465E7f2
// 0x17F6AD8Ef982297579C203069C1DbfFE4348c372
// 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678

