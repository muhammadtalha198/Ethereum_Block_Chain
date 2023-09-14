// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IERC20.sol";
import "./IERC721.sol";

contract Lender {
    using SafeMath for uint256;

    uint256 public adminFeeInBasisPoints = 200; //Admin fee 2% of Owna
    uint256 public constant maximumExpiration = 72 hours;
    uint256 public constant oneDay = 180; // 3600 ; // 86400; // 180

    address adminWallet; // Remove this extra variable.

    address secondWallet; // Remove thsi extra variable.

    address tokenAddress;

    address nftAddress;

    // Remove this extra struct and save the both variable in LoanDeatails to save gas cost.

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
        TimeDetail timeDetail; // Remove this code line too in case remove the TimeDetail struct.
    }

    mapping(uint256 => bool) public isNftExists; // Remove this extra mapping

    // remopve this extra mapping and add the idToNft(borrowed) variable in struct.

    mapping(uint256 => bool) public idToNft; // change idToNft to borrowed

    mapping(address => mapping(uint256 => bool)) public lenderOnNftId; // change lenderOnNftId to offeredAgin

    mapping(uint256 => LoanOffer[]) public requestAgainstNft;

    function fixedLoanOffer(
        uint256 duration,
        uint256 aprValue,
        uint256 minLoanOffer,
        uint256 maxLoanOffer,
        uint256 nftID,
        address borrowerAddress
    ) public {
        require(
            IERC721(nftAddress).borrwerOf(nftID) == borrowerAddress,
            "please give valid borrower address"
        );

        require(
            !idToNft[nftID],
            "Borrower Already Accepted the offer at this Nft ID"
        );
        require(
            !lenderOnNftId[msg.sender][nftID],
            "Lender cannot again Offer on same nftId"
        );

        require(duration != 0, "Duration of loan zero no acceptable");

        require(minLoanOffer > 0, "Minimum loan should be greater 0");
        require(
            maxLoanOffer > minLoanOffer,
            "Maximum should be greater than minimum loan"
        );

        require(
            maxLoanOffer.div(100).mul(aprValue).div(365).mul(
                duration.div(86400)
            ) <= maxLoanOffer.div(100).mul(25),
            "your intrest is increasing 25% of total for selected duration. please select proper duration."
        );

        // add a require check that apr must be > 0 to <= 101
        require(aprValue > 0, "Apr Cannot be 0");

        LoanDetail memory loanDetail = LoanDetail({
            apr: aprValue,
            minLoan: minLoanOffer,
            maxLoan: maxLoanOffer,
            loan: 0,
            acceptable_debt: 0
        });

        // Remove this struct geting initialize and add initialize both variable in loanDetail.
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

        // remove this extra code
        if (!isNftExists[fix.nftId]) {
            isNftExists[fix.nftId] = true;
        }

        // Use SafeTransfer from to transfer token in fixedLoanOffer.
        IERC20(tokenAddress).transferFrom(
            fix.lender,
            address(this),
            fix.loanDetail.maxLoan
        );
    }

    function flexibleLoanOffer(
        uint256 duration,
        uint256 aprValue,
        uint256 minLoanOffer,
        uint256 maxLoanOffer,
        uint256 nftID,
        uint256 acceptableDebt,
        address borrowerAddress
    ) public {
        require(
            IERC721(nftAddress).borrwerOf(nftID) == borrowerAddress,
            "please give valid borrower address"
        );

        require(
            !idToNft[nftID],
            "Borrower Already Accepted the offer at this Nft ID"
        );
        require(
            !lenderOnNftId[msg.sender][nftID],
            "Lender cannot again Offer on same nftId"
        );

        require(acceptableDebt > 2, "Maximum Acceptable Debt cannot be 0%");
        require(
            acceptableDebt <= 25,
            "Maximum Acceptable Debt cannot be more than 23%"
        );

        require(duration != 0, "Duration of loan zero no acceptable");

        require(minLoanOffer > 0, "Minimum loan should be greater 0");
        require(
            maxLoanOffer > minLoanOffer,
            "Maximum should be greater than minimum loan"
        );

        require(
            (
                (maxLoanOffer.mul(acceptableDebt.sub(2).mul(100)).div(10000))
                    .mul(365)
            ) /
                (maxLoanOffer.mul(aprValue.mul(100)).div(10000)) ==
                duration.div(86400),
            "Please Select a valid duration for flexible offering "
        );

        // add a require check that apr must be > 0 to <= 101
        require(aprValue > 0, "Apr Cannot be 0");

        LoanDetail memory loanDetail = LoanDetail({
            apr: aprValue,
            minLoan: minLoanOffer,
            maxLoan: maxLoanOffer,
            loan: 0,
            acceptable_debt: acceptableDebt - 2
        });

        // Remove this struct geting initialize and add initialize both variable in loanDetail.

        TimeDetail memory timeDetals = TimeDetail({
            durations: duration,
            startTime: block.timestamp
        });

        // Suggestion: change fix variable name to fkexible in flexibleLoanOffer.

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

        // Remove this extra code.
        if (!isNftExists[fix.nftId]) {
            isNftExists[fix.nftId] = true;
        }

        // Use SafeTransfer from to transfer token in fixedLoanOffer.
        IERC20(tokenAddress).transferFrom(
            fix.lender,
            address(this),
            fix.loanDetail.maxLoan
        );
    }

    function lendersFunds(uint256 nftID, uint256 offerID) public {
        LoanOffer memory offer = requestAgainstNft[nftID][offerID];

        require(offer.lender != address(0x0), "Offer not found");
        require(msg.sender == offer.lender, "Only Lender can Withdraw Funds");

        if (compareStrings(offer.status, "Rejected")) {
            // Use SafeTransfer from to transfer token in fixedLoanOffer.
            IERC20(tokenAddress).transfer(
                offer.lender,
                offer.loanDetail.maxLoan
            );

            // "requestAgainstNft" must be deleted before token transfer to secure it from reenterency attack.
            delete requestAgainstNft[nftID][offerID];
        } else if (
            compareStrings(offer.status, "Pending") &&
            block.timestamp - offer.timeDetail.startTime >= 72 hours
        ) {
            // Use SafeTransfer from to transfer token in fixedLoanOffer.
            IERC20(tokenAddress).transfer(
                offer.lender,
                offer.loanDetail.maxLoan
            );

            // "requestAgainstNft" must be deleted before token transfer to secure it from reenterency attack.
            delete requestAgainstNft[nftID][offerID];
        }
        // remove this extra else statement with require check "requestAgainstNft[nftID][offerID].loanDetail.maxLoan == 0"
        else {
            require(
                requestAgainstNft[nftID][offerID].loanDetail.maxLoan == 0,
                "Not eligible to with draw the fund"
            );
        }
    }

    function compareStrings(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
