// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
// import "hardhat/console.sol";

contract FlashLoan {
    
    
    using SafeMath for uint256;

    IERC20 public token1;
    IERC20 public token2;



    address owner;

    uint256 loanId;
    
    struct LoanDeatils {
        bool loanListed;
        bool borrowed;
        address loanGiver;
        address loanTaker;
        uint256 loanAmount;
        uint256 loanTime;
        uint256 loanStartTime;
        uint256 rewardPercentagePerDay;
        uint256 rewardAmount;
    }

    mapping (uint256 => LoanDeatils) public loanDetails;

    constructor(address _token1, address _token2){
            
            owner = msg.sender;

            token1 = IERC20(_token1);   
            token2 = IERC20(_token2);   
    }



    function giveLoan(uint256 _loanAmount, uint256 _loanTime, uint256 _rewardPercentagePerDay) public returns(uint256) {

        require(_loanAmount != 0);
        require(_loanTime != 0);
        require(_rewardPercentagePerDay != 0);
        

        loanId++;

        loanDetails[loanId].loanGiver  = msg.sender;
        loanDetails[loanId].loanAmount  = _loanAmount;
        loanDetails[loanId].loanTime  = _loanTime;
        loanDetails[loanId].rewardPercentagePerDay  = _rewardPercentagePerDay;
        loanDetails[loanId].loanListed  = true;

        token1.transferFrom(msg.sender,address(this),_loanAmount);

        return loanId;
    }

    function borrowLoan(uint256 _loanId, uint256 _loanAmountAgainst) public {
        
        require(_loanId != 0);
        require(loanDetails[_loanId].loanAmount == _loanAmountAgainst);
        require(loanDetails[_loanId].loanListed, "this load isnt exsted");
        require(!loanDetails[_loanId].borrowed);

        loanDetails[_loanId].loanTaker  = msg.sender;
        loanDetails[_loanId].loanStartTime  = block.timestamp;
        loanDetails[_loanId].borrowed  = true;

        token2.transferFrom(msg.sender,address(this),_loanAmountAgainst);
        token1.transfer(msg.sender,_loanAmountAgainst);

    }

    function payBackLoan(uint256 _loanId, uint256 _paidAmount) public {


        require(_loanId != 0,"id not zero");
        require(loanDetails[_loanId].loanListed, "this load isnt exsted");
        require(loanDetails[_loanId].borrowed, "not borrowed");
        require(loanDetails[_loanId].loanTaker == msg.sender, " not loan taker");


        uint256 reward = TotalReward(_loanId);


        require(_paidAmount >= reward.add(loanDetails[_loanId].loanAmount),"low paid amount" );

        loanDetails[_loanId].rewardAmount  = reward;

        token1.transferFrom(msg.sender,loanDetails[_loanId].loanGiver,_paidAmount);

        token2.transfer(msg.sender,loanDetails[_loanId].loanAmount);

    }

    function TotalReward(uint256 _loanId) public view returns(uint256){


        // uint256 totalDays = (block.timestamp - loanDetails[loanId].loanStartTime) / 60 / 60 / 24;
        uint256 initialTotalMinutes = (block.timestamp.sub(loanDetails[_loanId].loanStartTime)).div(60);


        
        require(initialTotalMinutes > loanDetails[_loanId].loanTime, "Time must greater");

        uint256 FinalTotalMinutes =initialTotalMinutes.sub(loanDetails[_loanId].loanTime);


        uint256 percentage = loanDetails[_loanId].rewardPercentagePerDay.mul(FinalTotalMinutes);

        uint256 value =  calculatePercentage(loanDetails[_loanId].loanAmount,percentage);

        return value;

    }


    function calculatePercentage(uint256 _amount, uint256 _percentage) public pure returns (uint256){
        _percentage = _percentage.mul(100);
        return _amount.mul(_percentage).div(10000);
    }
}
