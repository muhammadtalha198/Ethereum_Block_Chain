// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Borrower.sol";
 
contract Owna is Borrower {
    
    using SafeMath for uint256; // Safe math library for underflow/overflow value
    // ============ Immutable Variables ============
    event ownaPaid(address lender, uint256 nftID,uint256 offerID, uint256 amountNeedToPay);

      
    // ============ Constructor ============
    constructor(address admin, address secondAddress, address tokenAdd, address nftAdd){
            adminWallet = admin;
            secondWallet = secondAddress;   
            tokenAddress = tokenAdd;
            nftAddress = nftAdd;
    }

    function payableAmountForOwna (uint256 nftID,uint256 offerID) public view returns (uint256 payableAmount){
                 
                  LoanOffer memory offer = requestAgainstNft[nftID][offerID];
                  uint256 last_update_days;
                  uint256 timeDurationForBorrower;
                  uint256 timeDurationForOwna; 
                  uint256 last_update_second; 
                  uint256 intrestAmount;


                  if(offer.offerType==0){
                    FixedBorrow memory fixedBorrow = fixBorrow[nftID];
                    timeDurationForBorrower = fixedBorrow.lastUpdate.sub(fixedBorrow.startTime);
                    timeDurationForOwna = block.timestamp.sub(fixedBorrow.lastUpdate);
                    //12+12>419
                   if(timeDurationForBorrower.add(timeDurationForOwna)>offer.timeDetail.durations){        
                      last_update_second=timeDurationForOwna.sub(timeDurationForBorrower.add(timeDurationForOwna).sub(offer.timeDetail.durations));         
                     }
                     //419>12+12
                   else if(offer.timeDetail.durations>timeDurationForBorrower+timeDurationForOwna){
                       last_update_second=timeDurationForOwna; 
                    } 
                  last_update_days=last_update_second.div(oneDay); // 1,245 / 180 = 10.375
                        //  calculate interest by  multiply with dailyintrest
                        intrestAmount = last_update_days.mul(fixedBorrow.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
                          // dailyInterest(fixBorrow[nftID].loanAmount, offer.loanDetail.apr)); // 10 * 16301 = 163,010
                       
                      // remove debtPaid
                     intrestAmount=intrestAmount-fixedBorrow.debtPaid;
 
                         // add eightyPercent 
                     payableAmount=fixedBorrow.loanAmount.add(eightyPercent(intrestAmount));
                     return  payableAmount;
                   
                 }
                 else if(offer.offerType==1){ 
                    FlexibledBorrow memory flexibleOffer = flexibleBorrow[nftID];

                     timeDurationForOwna = block.timestamp.sub(flexibleOffer.lastUpdate); 
                    if(timeDurationForOwna>offer.timeDetail.durations){        
                      last_update_second=offer.timeDetail.durations;         
                     }
                   else if(offer.timeDetail.durations>timeDurationForOwna){
                       last_update_second=timeDurationForOwna; 
                    } 
                      last_update_days=last_update_second.div(oneDay); // 1,245 / 180 = 10.375
                        //  calculate interest by  multiply with dailyintrest
                         intrestAmount = last_update_days.mul(flexibleOffer.loanAmount.div(100).mul(offer.loanDetail.apr).div(365)).div(24);
                          // dailyInterest(flexibleBorrow[nftID].loanAmount, requestAgainstNft[nftID][offerID].loanDetail.apr)); // 10 * 16301 = 163,010
                        // remove debt
                         intrestAmount=intrestAmount-flexibleOffer.debtPaid;
                          // add eightyPercent 
                     payableAmount= flexibleOffer.loanAmount.add(eightyPercent(intrestAmount)); 
                    return payableAmount;
                 }

    }


// ============================ownaPay==========================>>

     function ownaPay(uint256 nftID,uint256 offerID) public onlyOwner  {

       require(requestAgainstNft[nftID][offerID].nftId !=0,"offer not exist");
         uint256 AmountNeedToPay = payableAmountForOwna(nftID, offerID); 
          IERC20(tokenAddress).transferFrom(adminWallet,requestAgainstNft[nftID][offerID].lender,AmountNeedToPay);
          IERC721(nftAddress).burn(nftID);
    
         if(requestAgainstNft[nftID][offerID].offerType==0){  
        require(fixBorrow[nftID].loanAmount!=0,"offer not exist");
              delete fixBorrow[nftID];  
              emit ownaPaid(requestAgainstNft[nftID][offerID].lender, nftID, offerID, AmountNeedToPay);
        }
        else if(requestAgainstNft[nftID][offerID].offerType==1){
           require(flexibleBorrow[nftID].loanAmount!=0,"offer not exist");
             delete flexibleBorrow[nftID]; 
               emit ownaPaid(requestAgainstNft[nftID][offerID].lender, nftID, offerID, AmountNeedToPay);
        }
//          removeNftId(nftID);
          delete requestAgainstNft[nftID][offerID];
    }



// ============================payableAmountByBorrower==========================>>
   function payableAmountForBorrower (uint256 nftID,uint256 offerID) public view returns (uint256){
                 if(requestAgainstNft[nftID][offerID].offerType==0){
                    uint256 interest = readDynamicInterest(nftID, offerID);
                  return fixBorrow[nftID].loanAmount.add(interest);
                  }else{
                    uint256 interest = readDynamicInterest(nftID, offerID);
                     return  flexibleBorrow[nftID].loanAmount.add(interest);
                    
                 }
    }

// ============================selAssetToOwna===================
  function sellAssetToOwna(uint256 nftID, uint256 offerID) public {
      require(msg.sender == requestAgainstNft[nftID][offerID].borrower,"Only Borrower can Sell");

      if(requestAgainstNft[nftID][offerID].offerType==0){
          require(fixBorrow[nftID].loanAmount!=0,"offer not exist");
          fixBorrow[nftID].isSold = true;    
       }
      else if(requestAgainstNft[nftID][offerID].offerType==1){
        require(flexibleBorrow[nftID].loanAmount!=0,"offer not exist");
          flexibleBorrow[nftID].isSold = true;
     }
  }
  
    // function updateAdminFee (uint256 newAdminFeeInBasisPoints) external onlyOwner{
    //     adminFeeInBasisPoints = newAdminFeeInBasisPoints;
    // }

 

}