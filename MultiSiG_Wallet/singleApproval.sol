// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Ownable {

    address[] private _owners;

    event OwnershipAdded(address indexed newOwner);
    event OwnershipRemoved(address indexed removedOwner);

    constructor(address[] memory initialOwners) {
        require(initialOwners.length > 0, "Initial owners list must not be empty");

        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), "Invalid initial owner address");
            _owners.push(initialOwners[i]);
            emit OwnershipAdded(initialOwners[i]);
        }
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Ownable: caller is not an owner");
        _;
    }

    function isOwner(address account) internal view returns (bool) {
        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == account) {
                return true;
            }
        }
        return false;
    }

    function owners() public view returns (address[] memory) {
        return _owners;
    }

    function addOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid owner address");
        require(!isOwner(newOwner), "Owner already exists");

        _owners.push(newOwner);
        emit OwnershipAdded(newOwner);
    }

    function removeOwnership(address ownerToRemove) public onlyOwner {
        require(isOwner(ownerToRemove), "Owner does not exist");

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == ownerToRemove) {
                _owners[i] = _owners[_owners.length - 1];
                _owners.pop();
                emit OwnershipRemoved(ownerToRemove);
                break;
            }
        }
    }
}

