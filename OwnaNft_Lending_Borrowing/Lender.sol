// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IERC20.sol";
import "./IERC721.sol";
// import "hardhat/console.sol";

contract Lender {
    using SafeMath for uint256; 

     // ============ Mutable Variables ============
    // uint256[] public listedNfts;

    // ============ Immutable Variables ============
    uint256 public adminFeeInBasisPoints = 200; //Admin fee 2% of Owna
    uint256 public constant maximumExpiration = 72 hours;
    uint256 public constant oneDay = 180; // 3600 ; // 86400; // 180

    address adminWallet;
    address secondWallet; 
    address tokenAddress;
    address nftAddress; 
   
    // ============ Structs ============
    struct TimeDetail {
        uint256 durations;
        uint256 startTime;
    }

    struct LoanDetail {
        uint256 apr;
        uint256 minLoan;
        uint256 maxLoan;
        uint256 loan;
        uint256 acceptable_debt;
    }

    struct LoanOffer {
        uint256 offerID;
        uint256 offerType; // 0 fixed ; 1 for flexible
        uint256 nftId;
        address lender;
        address borrower;
        string status;
        LoanDetail loanDetail;
        TimeDetail timeDetail;
    }

    // ============ Mappings ============
    mapping(uint256 => bool) public isNftExists;
    mapping(uint256 => bool) public idToNft;
    mapping(address => mapping(uint256 => bool)) public lenderOnNftId;
    mapping(uint256 => LoanOffer[]) public requestAgainstNft;


    // ============ Events ============
    event fixedLoan(
        uint256 fixedId,
        uint256 durations,
        uint256 apr,
        uint256 minLoan,
        uint256 maxLoan,
        uint256 startTime,
        uint256 nftId,
        address lender
    );
    event flexibleLoan(
        uint256 flexibleId,
        uint256 apr,
        uint256 minLoan,
        uint256 maxLoan,
        uint256 acceptable_debt,
        uint256 startTime,
        uint256 nftId,
        address lender
    );
    event lenderRecivedFunds(
        address lender,
        uint256 nftID,
        uint256 offerID,
        uint256 maxLoan
    );

    event lenderCancelledOffer(
        address lender,
        uint256 nftID,
        uint256 offerID
    );

    // function listedNft() public view returns (uint256[] memory) {
    //     return listedNfts;
    // }

    function fixedLoanOffer(uint256 duration, uint256 aprValue, uint256 minLoanOffer, uint256 maxLoanOffer, uint256 nftID, address borrowerAddress) public {
        require(IERC721(nftAddress).borrwerOf(nftID) == borrowerAddress,"please give valid borrower address");
        require(!idToNft[nftID],"Borrower Already Accepted the offer at this Nft ID");
        require(!lenderOnNftId[msg.sender][nftID],"Lender cannot again Offer on same nftId");
        require(duration != 0, "Duration of loan zero no acceptable");
        require(minLoanOffer > 0, "Minimum loan should be greater 0");
        require(maxLoanOffer > minLoanOffer,"Maximum should be greater than minimum loan");
        require(maxLoanOffer.div(100).mul(aprValue).div(365).mul(duration.div(86400)) <= maxLoanOffer.div(100).mul(25),"your intrest is increasing 25% of total for selected duration. please select proper duration.");
        require(aprValue > 0, "Apr Cannot be 0");

        LoanDetail memory loanDetail = LoanDetail({
            apr: aprValue,
            minLoan: minLoanOffer,
            maxLoan: maxLoanOffer,
            loan: 0,
            acceptable_debt: 0
        });
        
        TimeDetail memory timeDetals = TimeDetail({
            durations: duration,
            startTime: block.timestamp
        });

        LoanOffer memory fix = LoanOffer({
            offerID: requestAgainstNft[nftID].length,
            offerType: 0,
            nftId: nftID,
            lender: msg.sender,
            borrower: borrowerAddress,
            status: "Pending",
            timeDetail: timeDetals,
            loanDetail: loanDetail
        });

        requestAgainstNft[nftID].push(fix);
        lenderOnNftId[fix.lender][fix.nftId] = true;

        if (!isNftExists[fix.nftId]) {
            // IERC721(nftAddress).transferFrom(borrowerAddress, address(this), fix.nftId);
            isNftExists[fix.nftId] = true;
            // listedNfts.push(fix.nftId);
        }

        IERC20(tokenAddress).transferFrom(fix.lender,address(this),fix.loanDetail.maxLoan);
        
        emit fixedLoan(fix.offerID,fix.timeDetail.durations,fix.loanDetail.apr,fix.loanDetail.minLoan,fix.loanDetail.maxLoan,fix.timeDetail.startTime,fix.nftId,fix.lender
        
        );
    }


    function flexibleLoanOffer(uint256 duration,uint256 aprValue,uint256 minLoanOffer,uint256 maxLoanOffer,uint256 nftID,uint256 acceptableDebt,address borrowerAddress) public {
        require(IERC721(nftAddress).borrwerOf(nftID) == borrowerAddress,"please give valid borrower address");
        require(!idToNft[nftID],"Borrower Already Accepted the offer at this Nft ID");
        require(!lenderOnNftId[msg.sender][nftID],"Lender cannot again Offer on same nftId");
        require(acceptableDebt <= 25,"Maximum Acceptable Debt cannot be more than 23%");
        require(acceptableDebt > 2, "Maximum Acceptable Debt cannot be 0%");
        require(duration != 0, "Duration of loan zero no acceptable");
        require(minLoanOffer > 0, "Minimum loan should be greater 0");
        require(maxLoanOffer > minLoanOffer,"Maximum should be greater than minimum loan");
        require(((maxLoanOffer.mul(acceptableDebt.sub(2).mul(100)).div(10000)).mul(365)) / (maxLoanOffer.mul(aprValue.mul(100)).div(10000)) == duration.div(86400),"Please Select a valid duration for flexible offering ");
        require(aprValue > 0, "Apr Cannot be 0");

        LoanDetail memory loanDetail = LoanDetail({
            apr: aprValue,
            minLoan: minLoanOffer,
            maxLoan: maxLoanOffer,
            loan: 0,
            acceptable_debt: acceptableDebt - 2
        });

        TimeDetail memory timeDetals = TimeDetail({
            durations: duration,
            startTime: block.timestamp
        });

        LoanOffer memory fix = LoanOffer({
            offerID: requestAgainstNft[nftID].length,
            offerType: 1,
            nftId: nftID,
            lender: msg.sender,
            borrower: borrowerAddress,
            status: "Pending",
            timeDetail: timeDetals,
            loanDetail: loanDetail
        });

        requestAgainstNft[nftID].push(fix);
        lenderOnNftId[fix.lender][fix.nftId] = true;

        if (!isNftExists[fix.nftId]) {
            // IERC721(nftAddress).transferFrom(borrowerAddress, address(this), fix.nftId);
            isNftExists[fix.nftId] = true;
            // listedNfts.push(fix.nftId);
        }

        IERC20(tokenAddress).transferFrom(fix.lender,address(this),fix.loanDetail.maxLoan);
        
        emit flexibleLoan(fix.offerID,fix.loanDetail.apr,fix.loanDetail.minLoan,fix.loanDetail.maxLoan,acceptableDebt,fix.timeDetail.startTime,fix.nftId,fix.lender);
    }

    function lendersFunds(uint256 nftID, uint256 offerID) public {
        LoanOffer memory offer = requestAgainstNft[nftID][offerID];
        require(offer.lender != address(0x0), "Offer not found");
        require(msg.sender == offer.lender, "Only Lender can Withdraw Funds");


        if (compareStrings(offer.status, "Rejected")) {
            IERC20(tokenAddress).transfer(offer.lender,offer.loanDetail.maxLoan);
            delete requestAgainstNft[nftID][offerID];
        } 

        else if (compareStrings(offer.status, "Cancelled")){
            revert("Cannot Claim, Offer has already been cancelled");
            // require(false, "Cannot Claim, Offer has already been cancelled");
        }

        else if ( compareStrings(offer.status, "Pending") && block.timestamp - offer.timeDetail.startTime >= 72 hours) {
            IERC20(tokenAddress).transfer(offer.lender,offer.loanDetail.maxLoan);
            delete requestAgainstNft[nftID][offerID];
        } 
        else {
            require(
                requestAgainstNft[nftID][offerID].loanDetail.maxLoan == 0,
                "Not eligible to with draw the fund"
            );
        }
        emit lenderRecivedFunds(offer.lender,nftID,offerID,offer.loanDetail.maxLoan);
    }

    function cancelFixLoanOffer(uint256 nftId, uint256 offerId) external {
        
        // require(isNftExists[nftId], "NFT does not exist"); // extra
        // require(offerId < requestAgainstNft[nftId].length, "Invalid offer ID"); // extra
        require(keccak256(bytes(requestAgainstNft[nftId][offerId].status)) == keccak256(bytes("Pending")), "Cannot cancel a loan offer that is not pending or rejected");

        LoanOffer storage offer = requestAgainstNft[nftId][offerId];

        require(msg.sender == offer.lender, "Only lender can cancel the offer");
        require(offer.offerType == 0, "Offer type should be fixed");
        // require(keccak256(abi.encodePacked(offer.status)) != keccak256(abi.encodePacked("Cancelled")), "Offer already cancelled"); // extra
        
        offer.status = "Cancelled";

        IERC20(tokenAddress).transfer(offer.lender, offer.loanDetail.maxLoan);
        
        // Reset offer details to default values
        offer.offerID = 0;
        offer.offerType = 0;
        offer.nftId = 0;
        offer.lender = address(0);
        offer.borrower = address(0);
        offer.status = "";
        offer.timeDetail = TimeDetail(0, 0);
        offer.loanDetail = LoanDetail(0, 0, 0, 0, 0);

        emit lenderCancelledOffer (msg.sender, nftId, offerId);
    }


    // function removeNftId(uint256 id) internal {
    //     for (uint256 i = 0; i <= listedNfts.length - 1; i++) {
    //         if (listedNfts[i] == id) {
    //             listedNfts[i] = listedNfts[listedNfts.length - 1];
    //             listedNfts.pop();
    //             break;
    //         }
    //     }
    // }

    function compareStrings(string memory a, string memory b)public pure returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
