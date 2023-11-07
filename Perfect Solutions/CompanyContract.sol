// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DocumentStash is Ownable {

    constructor(address initialOwner) Ownable(initialOwner) {}
    
    using Counters for Counters.Counter;
    
    struct Company  {
        string companyID;
        string companyName;
        bool initialized;

        Counters.Counter productCounter;

        mapping(uint256 => Product) productMap;
    }

    struct Product  {
        uint256 productID;
        string productName;
        bool initialized;

        Counters.Counter claimsCounter;

        mapping(uint256 => Claim) claimMap;
    }

    struct Claim {
        uint256 claimID;
        string claimName;
        bool initialized;

        Counters.Counter documentsCounter;

        mapping(uint256 => Document) documentMap;
    }

    struct Document {
        uint256 documentID;
        string documentHash;
        string documentName;
        uint256 timestamp;
        bool initialized;
        
        string[] signatures;
    }

    mapping(string => Company) public companyMap;

    event CompanyCreated(string ID, string name);
    event ProductCreated(uint256 ID, string name);
    event ClaimCreated(uint256 ID, string name);
    event DocumentCreated(uint256 ID, string name, string dochash);

    function createNewCompany(string memory _companyID, string memory _companyName) public onlyOwner {
        require(bytes(_companyID).length == 6, "Company ID should be of length 6");
        require(companyMap[_companyID].initialized != true, "Company already exists");

        companyMap[_companyID].companyID = _companyID;
        companyMap[_companyID].companyName = _companyName;
        companyMap[_companyID].initialized = true;

        emit CompanyCreated(_companyID, _companyName);
    }

    function createNewProduct(string memory _companyID, string memory _productName) public onlyOwner {
        
        require(companyMap[_companyID].initialized == true, "Company does not exist");

        uint256 _productID = companyMap[_companyID].productCounter.current();

        companyMap[_companyID].productMap[_productID].productID = _productID;
        companyMap[_companyID].productMap[_productID].productName = _productName;
        companyMap[_companyID].productMap[_productID].initialized = true;

        emit ProductCreated(_productID, _productName);

        companyMap[_companyID].productCounter.increment();
    }

    function createNewClaim(string memory _companyID, string memory _claimName) public onlyOwner {
        
        require(companyMap[_companyID].initialized == true, "Company does not exist");

        uint256 claimID = companyMap[_companyID].claimsCounter.current();

        companyMap[_companyID].claimMap[claimID].claimID = claimID;
        companyMap[_companyID].claimMap[claimID].claimName = _claimName;
        companyMap[_companyID].claimMap[claimID].initialized = true;

        emit ClaimCreated(claimID, _claimName);

        companyMap[_companyID].claimsCounter.increment();
    }

    function createNewDocument(string memory _companyID, uint256 _claimID, string memory _documentHash, string memory _documentName) public onlyOwner {
        require(companyMap[_companyID].initialized == true, "Company does not exist");
        require(companyMap[_companyID].claimMap[_claimID].initialized == true, "Claim does not exit");
        
        uint256 documentID = companyMap[_companyID].claimMap[_claimID].documentsCounter.current();

        companyMap[_companyID].claimMap[_claimID].documentMap[documentID].documentID = documentID;
        companyMap[_companyID].claimMap[_claimID].documentMap[documentID].documentName = _documentName;
        companyMap[_companyID].claimMap[_claimID].documentMap[documentID].documentHash = _documentHash;
        companyMap[_companyID].claimMap[_claimID].documentMap[documentID].timestamp = block.timestamp;
        companyMap[_companyID].claimMap[_claimID].documentMap[documentID].initialized = true;

        emit DocumentCreated(documentID, _documentName, _documentHash);

        companyMap[_companyID].claimMap[_claimID].documentsCounter.increment();
    }

    function addNewSignatures(string memory _companyID, uint256 _claimID, uint256 _documentID, string[] memory _signatures) public onlyOwner {
        
        require(companyMap[_companyID].initialized == true, "Company does not exist");
        require(companyMap[_companyID].claimMap[_claimID].initialized == true, "Claim does not exit");
        require(companyMap[_companyID].claimMap[_claimID].documentMap[_documentID].initialized == true, "Document does not exist");

        for (uint256 i = 0; i < _signatures.length ; i++) {
            companyMap[_companyID].claimMap[_claimID].documentMap[_documentID].signatures.push(_signatures[i]);
        }
    }

    function getClaim(string memory _companyID, uint256 _claimID) public view returns (Document[] memory, string memory) {
        require(companyMap[_companyID].initialized == true, "Company does not exist");
        require(companyMap[_companyID].claimMap[_claimID].initialized == true, "Claim does not exit");

        uint256 numberOfDocuments = companyMap[_companyID].claimMap[_claimID].documentsCounter.current();

        Document[] memory documents = new Document[](numberOfDocuments);

        for (uint256 i = 0; i < numberOfDocuments ; i++) {
            documents[i] = companyMap[_companyID].claimMap[_claimID].documentMap[i];
        }

        return (documents, companyMap[_companyID].claimMap[_claimID].claimName);
    }

    function getClaimsCounter(string memory _companyID) public view returns(uint256) {
        require(companyMap[_companyID].initialized == true, "Company does not exist");
        return  companyMap[_companyID].claimsCounter.current();
    }

    function getDocumentsCounter(string memory _companyID, uint256 _claimID) public view returns(Counters.Counter memory) {
        require(companyMap[_companyID].initialized == true, "Company does not exist");
        require(companyMap[_companyID].claimMap[_claimID].initialized == true, "Claim does not exit");

        return companyMap[_companyID].claimMap[_claimID].documentsCounter;
    }
}
