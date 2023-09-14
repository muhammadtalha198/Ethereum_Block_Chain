// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Lender.sol";
// import "hardhat/console.sol";


contract Borrower is Lender {

    // ============ Mutable Variables ============
       using SafeMath for uint256;

    // ============ Structs ============
    struct FixedBorrow {
        uint256 nftId;
        bool nft;
        uint256 loanAmount; 
        uint256 debtPaid; 
        bool isEntryFeePaid;
        bool isSold;
        uint256 lastUpdate;
        uint256 startTime;
 
    }
    
    struct FlexibledBorrow{
      uint256 nftId;
        bool nft;
        uint256 loanAmount; 
        uint256 debtPaid; 
        bool isEntryFeePaid;
        bool isSold;
        uint256 lastUpdate;
        uint256 startTime;
           } 

 
    // ============ Mappings ============
    mapping (uint256=>FixedBorrow) public fixBorrow;
    mapping (uint256=>FlexibledBorrow) public flexibleBorrow;
    
   
    
    mapping(uint256=>bool) public isBorrowing;
     // *********************

    // ============ Events ============
    // event AdminFeeUpdated(uint256 newAdminFee);
    event fixBorrowEvent(address borrower, uint256 nftID, uint256 offerID, uint256 loanAmount,address lender, string status, bool isEntryFeePaid, uint256 startTime, uint256 lastUpdate);
    event flexibleBorrowEvent(address borrower, uint256 nftID, uint256 offerID, uint256 loanAmount,address lender, string status, bool isEntryFeePaid, uint256 startTime, uint256 lastUpdate);
    event loanFixRepaid(address borrower, uint256 nftID, uint256 offerID, uint256 cummulatedInterest);
    event loanFlexibleRepaid(address borrower, uint256 nftID, uint256 offerID, uint256 cummulatedInterest);
     // ============ Functions ============
   
    function borrowFixLoan(uint256 nftId ,uint256 offerID ,uint256 amount) public {

        LoanOffer memory offer = requestAgainstNft[nftId][offerID];
        
        require(requestAgainstNft[nftId][offerID].nftId !=0,"offer not exist");
        require(!fixBorrow[offer.nftId].nft,"Borrower Already Accepted the offer");
        require( block.timestamp-offer.timeDetail.startTime < maximumExpiration ,"Loan Fixed offering  was only escrow for 72 hours");
        require(requestAgainstNft[nftId][offerID].offerType==0,"Not existing Fixed Loan Offering id");
        require(msg.sender == offer.borrower,"You are not borrower against this NFT");
        require(!isBorrowing[nftId] , "Already borrowed the  loan against nft");
        require(amount >= requestAgainstNft[nftId][offerID].loanDetail.minLoan && amount <= requestAgainstNft[nftId][offerID].loanDetail.maxLoan, "Amount should be in MinLoan and MaxLoan Range" );

        uint256 remainLoan = offer.loanDetail.maxLoan - amount; // 6000
        isBorrowing[nftId] = true;
        fixBorrow[offer.nftId].nft = true;
        IERC20(tokenAddress).transfer(msg.sender, amount); // 7000      
        IERC20(tokenAddress).transfer(offer.lender,remainLoan);
        idToNft[nftId] = true;

        // Store val in Structure of FixBorrow
        requestAgainstNft[nftId][offerID].status = "Accepted"; 
        requestAgainstNft[nftId][offerID].loanDetail.loan = amount;  
        fixBorrow[offer.nftId].nftId = offer.nftId; 
        fixBorrow[offer.nftId].loanAmount = amount; 
        fixBorrow[offer.nftId].isEntryFeePaid = false;
        fixBorrow[offer.nftId].isSold = false;
        fixBorrow[offer.nftId].lastUpdate = block.timestamp;
        fixBorrow[offer.nftId].startTime = block.timestamp;   
        
     for(uint256 i = 0; i < requestAgainstNft[offer.nftId].length ;i++){

// =====> we will just update the object of lender request attribute pending to rejected
      if(requestAgainstNft[offer.nftId][i].offerID!=offer.offerID){
        requestAgainstNft[offer.nftId][i].status="Rejected";
      }
 
                     }
    
    emit fixBorrowEvent(msg.sender, nftId, offerID, fixBorrow[offer.offerID].loanAmount, offer.lender, requestAgainstNft[nftId][offerID].status,fixBorrow[offer.nftId].isEntryFeePaid, fixBorrow[offer.nftId].startTime , fixBorrow[offer.nftId].lastUpdate );
    }
    
    function borrowFlexibleLoan (uint256 nftId ,uint256 offerID ,uint256 amount) public {
         
        LoanOffer memory offer =   requestAgainstNft[nftId][offerID];
        require(!fixBorrow[offer.nftId].nft,"Borrower Already Accepted the offer");
        require(requestAgainstNft[nftId][offerID].nftId !=0,"offer not exist");
        require(block.timestamp-offer.timeDetail.startTime < maximumExpiration,"Loan Fixed offering  was only escrow for 72 hours");
        require(requestAgainstNft[nftId][offerID].offerType==1,"Not existing flexible Loan Offering id");
        require(msg.sender == offer.borrower,"You are not borrower against this NFT");
        require(!isBorrowing[nftId] , "Already borrowed the  loan against nft");
        require(amount >= requestAgainstNft[nftId][offerID].loanDetail.minLoan && amount <= requestAgainstNft[nftId][offerID].loanDetail.maxLoan, "Amount should be in MinLoan and MaxLoan Range" );

        uint256 remainLoan =offer.loanDetail.maxLoan - amount; // 6000
  
        isBorrowing[nftId] = true;
        flexibleBorrow[offer.nftId].nft = true;
  
        IERC20(tokenAddress).transfer(msg.sender,  amount); // 7000      
        IERC20(tokenAddress).transfer(offer.lender,remainLoan);

        idToNft[nftId] = true;

        // Store val in Structure of FixBorrow
        requestAgainstNft[nftId][offerID].status = "Accepted"; 
        requestAgainstNft[nftId][offerID].loanDetail.loan = amount; 
        
        flexibleBorrow[offer.nftId].nftId =offer.nftId;
        flexibleBorrow[offer.nftId].loanAmount = amount;
        flexibleBorrow[offer.nftId].isEntryFeePaid = false;
        flexibleBorrow[offer.nftId].isSold = false;
        flexibleBorrow[offer.nftId].lastUpdate = block.timestamp;
        flexibleBorrow[offer.nftId].startTime = block.timestamp; 
       
     for(uint256 i = 0; i < requestAgainstNft[offer.nftId].length ;i++){
       if(requestAgainstNft[offer.nftId][i].offerID!=offer.offerID){
        requestAgainstNft[offer.nftId][i].status="Rejected";
      }
    }
    emit flexibleBorrowEvent( msg.sender, nftId, offerID, flexibleBorrow[offer.nftId].loanAmount,offer.lender, requestAgainstNft[nftId][offerID].status, flexibleBorrow[offer.nftId].isEntryFeePaid, flexibleBorrow[offer.nftId].startTime , flexibleBorrow[offer.nftId].lastUpdate );
    }



// ============================================repayFixLoan=====================
    function repayFixLoan(uint256 nftID,uint256 offerID,uint256 selectAmount) internal {
         FixedBorrow memory fixedBorrow = fixBorrow[nftID];
        LoanOffer memory offer = requestAgainstNft[nftID][offerID];
        uint256  entryFee=0;
 
       // check is entery fee paid or not 
       if(fixedBorrow.isEntryFeePaid==false){
       entryFee =  percentageCalculate(fixedBorrow.loanAmount); // 
        require(selectAmount>=entryFee,"amount should be atleast your entery fee");
        fixBorrow[fixedBorrow.nftId].isEntryFeePaid = true;
        selectAmount-=entryFee;
         }
       // calculate intrest 
        uint256 last_update_second =block.timestamp-fixedBorrow.lastUpdate;  
         uint256 intrestAmount = last_update_second.div(oneDay).mul(fixedBorrow.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
        // transfer to contract 
         IERC20(tokenAddress).transferFrom(offer.borrower,address(this),selectAmount+entryFee);
    
    //   =======> find if amount is more then just intrest af user also paying the intrest. also minus it from loan and send to the lender with 20% amount 
     if(selectAmount+fixBorrow[nftID].debtPaid+entryFee>intrestAmount+entryFee){
        uint256 intrestAmountNeedToSend=intrestAmount-fixBorrow[nftID].debtPaid;
 
        // send 20% percent value
        IERC20(tokenAddress).transfer(secondWallet, intrestAmountNeedToSend.sub(eightyPercent(intrestAmountNeedToSend))+entryFee); // 20 % to owna => in Contract = 80% + 7000
        // send 80% percent value
        IERC20(tokenAddress).transfer(offer.lender,eightyPercent(intrestAmountNeedToSend));

        uint256 loanPay = selectAmount-intrestAmountNeedToSend;
            // if user send more then value of loan 
            if(loanPay>fixedBorrow.loanAmount){
               IERC20(tokenAddress).transfer(offer.lender,fixedBorrow.loanAmount);
               IERC721(nftAddress).burn(fixedBorrow.nftId);
               delete fixBorrow[nftID];
               delete requestAgainstNft[nftID][offerID];
//               removeNftId(nftID);
             }
             // if user send less then value of loan 
          else if(fixedBorrow.loanAmount-loanPay>0){
              fixBorrow[nftID].lastUpdate = block.timestamp;
              fixBorrow[nftID].debtPaid=0;
              fixBorrow[offer.nftId].loanAmount = fixBorrow[fixedBorrow.nftId].loanAmount-loanPay;
              IERC20(tokenAddress).transfer(offer.lender,loanPay);
             }
                // if user send equal value of loan 
         else if(fixedBorrow.loanAmount-loanPay==0){ 
             IERC20(tokenAddress).transfer(offer.lender,loanPay);
             IERC721(nftAddress).burn(fixedBorrow.nftId);
               delete fixBorrow[nftID];
               delete requestAgainstNft[nftID][offerID];
//               removeNftId(nftID);
         
           }
     }
     // if amount only for. entery fee and interest
     else if(selectAmount+fixBorrow[nftID].debtPaid+entryFee<=intrestAmount+entryFee){
        fixBorrow[nftID].debtPaid+=selectAmount; 
        // trnasfer 20% of intrest 
        IERC20(tokenAddress).transfer(secondWallet, selectAmount.sub(eightyPercent(selectAmount))+entryFee); // 20 % to owna => in Contract = 80% + 7000
          // trnasfer 80% of intrest 
        IERC20(tokenAddress).transfer(offer.lender,eightyPercent(selectAmount));

     }
     
 emit loanFixRepaid(offer.borrower, nftID, offerID, intrestAmount );
           } 
       
         
      
  // =======================repayLoan=============================>>


    function repayLoan(uint256 nftID,uint256 offerID,uint256 selectAmount) public {
      LoanOffer memory offer = requestAgainstNft[nftID][offerID]; 
   
       require(msg.sender == offer.borrower,"Only Borrower can pay the loan");
        require(selectAmount>0,"amount should not be zero");

        if(offer.offerType==0){
        
        
        require(fixBorrow[nftID].isSold == false, "Cannot Repay, asset have Sold out");
        require(block.timestamp.sub(fixBorrow[nftID].startTime) < offer.timeDetail.durations ,
           "You cannot Repay After Selected Time period");
        require(fixBorrow[nftID].loanAmount!=0,"offer not exist");
             repayFixLoan(  nftID,  offerID,selectAmount);
       
       
        }
        else if(offer.offerType==1){


           require(flexibleBorrow[nftID].isSold == false, "Cannot Repay, asset have Sold out");
         //  If the customer already pays interest and doesn't reimbursement, we save the interest and give relief in case of extending the repayment period
          uint256 previousdaysintrestPaid = flexibleBorrow[nftID].debtPaid.div(flexibleBorrow[offer.nftId].loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24).mul(oneDay);
            // dailyInterest(flexibleBorrow[nftID].loanAmount, offer.loanDetail.apr)).mul(oneDay);
            require(block.timestamp.sub(flexibleBorrow[nftID].lastUpdate) < offer.timeDetail.durations+previousdaysintrestPaid
            ,"You cannot Repay After Selected Time period");
            require(flexibleBorrow[nftID].loanAmount!=0,"offer not exist");
            repayFlexible(nftID,offerID,selectAmount);


        }
    }
 
    function repayFlexible(uint256 nftID,uint256 offerID,uint256 selectAmount) internal{
        
        FlexibledBorrow memory flexibleOffer = flexibleBorrow[nftID];
        LoanOffer memory offer = requestAgainstNft[nftID][offerID];

        uint256  entryFee=0;
          // check is entery fee paid or not 
       if(flexibleOffer.isEntryFeePaid==false){
       entryFee=  percentageCalculate(flexibleOffer.loanAmount); // 
      require(selectAmount>=entryFee,"amount should be atleast your entery fee");
        flexibleBorrow[flexibleOffer.nftId].isEntryFeePaid = true;
         selectAmount-=entryFee;
         }
       // calculate intrest 
        uint256 last_update_second =block.timestamp-flexibleOffer.lastUpdate;  
        uint256 last_update_days=last_update_second.div(oneDay); 
        uint256 intrestAmount = last_update_days.mul(flexibleOffer.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
          // dailyInterest(flexibleOffer.loanAmount, offer.loanDetail.apr));
        // transfer to contract 
      IERC20(tokenAddress).transferFrom(offer.borrower,address(this),selectAmount+entryFee); 
   
       //   =======> find if amount is more then just intrest af user also paying the intrest. also minus it from loan and send to the lender with 20% amount 
     if(selectAmount+flexibleBorrow[nftID].debtPaid+entryFee>intrestAmount+entryFee){
       
        uint256 intrestAmountNeedToSend=intrestAmount-flexibleBorrow[nftID].debtPaid;
 
        
         // send 20% percent value
        IERC20(tokenAddress).transfer(secondWallet, intrestAmountNeedToSend.sub(eightyPercent(intrestAmountNeedToSend))+entryFee); // 20 % to owna => in Contract = 80% + 7000
        // send 80% percent value
        IERC20(tokenAddress).transfer(offer.lender, eightyPercent(intrestAmountNeedToSend));

        uint256 loanPay = selectAmount-intrestAmountNeedToSend;
          
          if(loanPay>flexibleOffer.loanAmount){
                // if user send more then value of loan 
              IERC20(tokenAddress).transfer(offer.lender,flexibleOffer.loanAmount);
               IERC721(nftAddress).burn(nftID);
               delete flexibleBorrow[nftID];
               delete requestAgainstNft[nftID][offerID];
//               removeNftId(nftID);
             }
          else if(flexibleOffer.loanAmount-loanPay==0){  
                 // if user send equal  value of loan 
             IERC20(tokenAddress).transfer(offer.lender,loanPay);
             IERC721(nftAddress).burn(nftID);
               delete flexibleBorrow[nftID];
               delete requestAgainstNft[nftID][offerID];
//               removeNftId(nftID);
         
            }
            else if(flexibleOffer.loanAmount-loanPay>0){
                   // if user send less then value of loan 
              flexibleBorrow[nftID].lastUpdate = block.timestamp;
              flexibleBorrow[offer.nftId].startTime = block.timestamp;
              flexibleBorrow[nftID].debtPaid=0;
              flexibleBorrow[offer.nftId].loanAmount = flexibleBorrow[nftID].loanAmount-loanPay;
              IERC20(tokenAddress).transfer(offer.lender,loanPay);
             }
              

     }
     else if(selectAmount+fixBorrow[nftID].debtPaid+entryFee<=intrestAmount+entryFee){

        flexibleBorrow[nftID].debtPaid+=selectAmount;
 
        // transfer 20 percent value 
        IERC20(tokenAddress).transfer(secondWallet, selectAmount.sub(eightyPercent(selectAmount))+entryFee); // 20 % to owna => in Contract = 80% + 7000
        // transfer 18 percent value 
        IERC20(tokenAddress).transfer(offer.lender,eightyPercent(selectAmount));

     }
   
    
    emit loanFlexibleRepaid(offer.borrower , nftID, offerID, intrestAmount);
    }

    function readDynamicInterest(uint256 nftID,uint256 offerID) public view returns (uint256)
     {

         LoanOffer memory offer = requestAgainstNft[nftID][offerID];

         if(offer.offerType==0){
         FixedBorrow memory fixedBorrow = fixBorrow[nftID];
         uint256 last_update_second = block.timestamp-fixedBorrow.lastUpdate; // 1672140642 -  1672139397 =  1,245 
         uint256 last_update_days=last_update_second.div(oneDay); // 1,245 / 180 = 10.375
         uint256 intrestAmount = last_update_days.mul(fixedBorrow.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
          //  dailyInterest(fixedBorrow.loanAmount, offer.loanDetail.apr)); // 10 * 16301 = 163,010

     
        if(fixedBorrow.isEntryFeePaid==false){
         intrestAmount= intrestAmount.add(percentageCalculate(fixedBorrow.loanAmount)); // 
        }
         return intrestAmount-fixBorrow[nftID].debtPaid;
         }
         else {
         FlexibledBorrow memory flexibleOffer = flexibleBorrow[nftID]; 
         uint256 last_update_second =block.timestamp-flexibleOffer.lastUpdate; // 1672140642 -  1672139397 =  1,245 
         uint256 last_update_days=last_update_second.div(oneDay); // 1,245 / 180 = 10.375
         uint256 intrestAmount = last_update_days.mul(flexibleOffer.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
          //  dailyInterest(flexibleOffer.loanAmount, offer.loanDetail.apr)); // 10 * 16301 = 163,010
      
         if(flexibleOffer.isEntryFeePaid==false){
         intrestAmount= intrestAmount.add(percentageCalculate(flexibleOffer.loanAmount)); // 
          }
         return intrestAmount-flexibleBorrow[nftID].debtPaid;
         }
         
       }

    // 2% formula
    function percentageCalculate ( uint256 value ) public view returns(uint256){
      return value.div(100).mul(adminFeeInBasisPoints)/100;
        
    } 

    // daily Fix interest
    function hourlyInterest (uint256 value, uint256 apr) public pure returns(uint256) {
           return value.div(100).mul(apr).div(365).div(24);
    } 

  
    // 80 %
    function eightyPercent(uint256 value) public pure returns (uint256){
      //  uint256 _eightyPercent = 8000; // 80 %
          return value.mul(8000).div(10000); // 80% of cumulated interest (1467)
    
    }

    modifier onlyOwner {
        require(msg.sender == adminWallet, "That's only owner can run this function");
        _;
    }
}
 