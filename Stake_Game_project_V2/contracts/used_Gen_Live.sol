
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC20 {
   
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)external returns (bool);
    function allowance(address owner, address spender)external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract GenTokenCon is IERC20 {
    
    using SafeMath for uint256;

    string private _name = "GenToken";
    string private _symbol = "FGEN";
    uint8 private _decimals = 18;

    address public contractOwner;
    address public contractAddress;
    
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    
    uint256 private constant MAX = ~uint256(0);
    uint256 internal _totalSupply = 200000 *10**18; //  200k _totalSupply
    
    mapping(address => bool) isExcludedFromFee;
    mapping(address => bool) public blackListed;
    mapping(address => bool) public whiteListed;
    address[] internal _excluded;
    
    uint256 public _arenaFee = 200; // 200 = 2.00%
    uint256 public _winnerFee = 100; // 100 = 1.00%
    uint256 public _burningFee = 200; // 200 = 2.0%
    uint256 public _lpFee = 400; // 400 = 4%
    uint256 public _insuranceFee = 400; // 400 = 4%
    uint256 public _treasuryFee = 200; // 200 = 2%
    uint256 public _referalFee = 100; // 100 = 1%
    uint256 public _selltreasuryFee = 300; // 300 = 3%
    uint256 public _sellinsuranceFee = 500; // 500 = 5%
    uint256 public _inbetweenFee_ = 4000; // 4000 = 40%

    
    uint256 public _arenaFeeTotal;
    uint256 public _winnerFeeTotal;
    uint256 public _burningFeeTotal;
    uint256 public _lpFeeTotal;
    uint256 public _insuranceFeeTotal;
    uint256 public _sellinsuranceFeeTotal;
    uint256 public _selltreasuryFeeTotal;
    uint256 public _treasuryFeeTotal;
    uint256 public _referalFeeTotal;
    uint256 public _inbetweenFeeTotal;

    address public arenaAddress  = 0x2501E79052e090de1529F9bc2EE761A89F62d82e;      // arenaAddress
    address public winnerAddress  = 0x79F1f75afEaed3494db6eC37683Bf9420F29e7A6;      // winnerCircleAddress
    address public burningAddress;  // 0x000000000000000000000000000000000000dead  Burning Address add after deployment
    address public lpAddress = 0x3e4993839f7B99C0Ac66048c3dFD58e0af548FD4;          // lpAddress liquidity pool
    address public insuranceAddress = 0xEBFe69037B45bDd21aDbb6DCD2E11e1f05C29d18;      // insuranceAddress
    address public treasuryAddress = 0x9Fe316f151F1Cb2022bc376B1073751f1B1a2414;      // treasuryAddress
    address public referalAddress = 0x46BADB2c0c352E05fDb58f8F84751210325A3DA5;      // referalAddress /Markiting 
    address public inbetweenAddress = 0x46BADB2c0c352E05fDb58f8F84751210325A3DA5;      // inbetweenAddress
    
    

    constructor() {

        contractOwner = msg.sender;
        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true;
        _balances[msg.sender] = _totalSupply;

    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public override view returns (uint256) {
         return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override virtual returns (bool) {
       _transfer(msg.sender,recipient,amount);
        return true;
    }

    function allowance(address owner, address spender) public override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override virtual returns (bool) {
        _transfer(sender,recipient,amount);
               
        _approve(sender,msg.sender,_allowances[sender][msg.sender].sub( amount,"ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }


    function _transfer(address sender, address recipient, uint256 amount) private {

        require(!blackListed[msg.sender], "You are blacklisted so you can not Transfer Gen tokens.");
        require(!blackListed[recipient], "blacklisted address canot be able to recieve Gen tokens.");
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 transferAmount = amount;

        if(isExcludedFromFee[sender] && recipient == contractAddress){
            transferAmount = collectFee(sender,amount);     
        }
        else if(whiteListed[sender] || whiteListed[recipient]){
            transferAmount = amount;     
        }
        else{

            if(isExcludedFromFee[sender] && isExcludedFromFee[recipient]){
                transferAmount = amount;
            }
            if(!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]){
                transferAmount = betweencollectFee(sender,amount);
            }
            if(isExcludedFromFee[sender] && !isExcludedFromFee[recipient]){
                transferAmount = collectFee(sender,amount);
            }
            if(!isExcludedFromFee[sender] && isExcludedFromFee[recipient]){
                transferAmount = SellcollectFee(sender,amount);
            }
        }   

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(transferAmount);
        
        emit Transfer(sender, recipient, transferAmount);
    }

    function decreaseTotalSupply(uint256 amount) public onlyOwner {
        _totalSupply =_totalSupply.sub(amount);

    }

    function setContractAddress(address _contractAddress) public onlyOwner{
            contractAddress = _contractAddress;
    }

    function _mint(address account, uint256 amount) public onlyOwner {
       
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
    }
    
    function _burn(address account, uint256 amount) public onlyOwner {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
    }
    
    
    function collectFee(address account, uint256 amount/*, uint256 rate*/) private returns (uint256) {
        
        uint256 transferAmount = amount;
        
        uint256 arenaFee = amount.mul(_arenaFee).div(10000);
        uint256 winnerFee = amount.mul(_winnerFee).div(10000);
        uint256 burningFee = amount.mul(_burningFee).div(10000);
        uint256 lpFee = amount.mul(_lpFee).div(10000);
        uint256 insuranceFee = amount.mul(_insuranceFee).div(10000);
        uint256 treasuryFee = amount.mul(_treasuryFee).div(10000);
        uint256 referalFee = amount.mul(_referalFee).div(10000);

        if (burningFee > 0){
            transferAmount = transferAmount.sub(burningFee);
            _balances[burningAddress] = _balances[burningAddress].add(burningFee);
            _burningFeeTotal = _burningFeeTotal.add(burningFee);
            emit Transfer(account,burningAddress,burningFee);
        }
        
        if (lpFee > 0){
            transferAmount = transferAmount.sub(lpFee);
            _balances[lpAddress] = _balances[lpAddress].add(lpFee);
            _lpFeeTotal = _lpFeeTotal.add(lpFee);
            emit Transfer(account,lpAddress,lpFee);
        }

        if(arenaFee > 0){
            transferAmount = transferAmount.sub(arenaFee);
            _balances[arenaAddress] = _balances[arenaAddress].add(arenaFee);
            _arenaFeeTotal = _arenaFeeTotal.add(arenaFee);
            emit Transfer(account,arenaAddress,arenaFee);
        }
     
        if(winnerFee > 0){
            transferAmount = transferAmount.sub(winnerFee);
            _balances[winnerAddress] = _balances[winnerAddress].add(winnerFee);
            _winnerFeeTotal = _winnerFeeTotal.add(winnerFee);
            emit Transfer(account,winnerAddress,winnerFee);
        }
        if(insuranceFee > 0){
            transferAmount = transferAmount.sub(insuranceFee);
            _balances[insuranceAddress] = _balances[insuranceAddress].add(insuranceFee);
            _insuranceFeeTotal = _insuranceFeeTotal.add(insuranceFee);
            emit Transfer(account,insuranceAddress,insuranceFee);
        }
        if(treasuryFee > 0){
            transferAmount = transferAmount.sub(treasuryFee);
            _balances[treasuryAddress] = _balances[treasuryAddress].add(treasuryFee);
            _treasuryFeeTotal = _treasuryFee.add(treasuryFee);
            emit Transfer(account,treasuryAddress,treasuryFee);
        }
        if(referalFee > 0){
            transferAmount = transferAmount.sub(referalFee);
            _balances[referalAddress] = _balances[referalAddress].add(referalFee);
            _referalFeeTotal = _referalFee.add(referalFee);
            emit Transfer(account,referalAddress,referalFee);
        }
        
       
        return transferAmount;
    }


    function SellcollectFee(address account, uint256 amount/*, uint256 rate*/) private  returns (uint256) {
        
        uint256 transferAmount = amount;
        
        uint256 arenaFee = amount.mul(_arenaFee).div(10000);
        uint256 winnerFee = amount.mul(_winnerFee).div(10000);
        uint256 burningFee = amount.mul(_burningFee).div(10000);
        uint256 lpFee = amount.mul(_lpFee).div(10000);
        uint256 sellinsuranceFee = amount.mul(_sellinsuranceFee).div(10000);
        uint256 selltreasuryFee = amount.mul(_selltreasuryFee).div(10000);
        uint256 referalFee = amount.mul(_referalFee).div(10000);

        if (burningFee > 0){
            transferAmount = transferAmount.sub(burningFee);
            _balances[burningAddress] = _balances[burningAddress].add(burningFee);
            _burningFeeTotal = _burningFeeTotal.add(burningFee);
            emit Transfer(account,burningAddress,burningFee);
        }

        if (lpFee > 0){
            transferAmount = transferAmount.sub(lpFee);
             _balances[lpAddress] = _balances[lpAddress].add(lpFee);
            _lpFeeTotal = _lpFeeTotal.add(lpFee);
            emit Transfer(account,lpAddress,lpFee);
        }

        if(arenaFee > 0){
            transferAmount = transferAmount.sub(arenaFee);
             _balances[arenaAddress] = _balances[arenaAddress].add(arenaFee);
            _arenaFeeTotal = _arenaFeeTotal.add(arenaFee);
            emit Transfer(account,arenaAddress,arenaFee);
        }
        
        //@dev BuyBackv2 fee
        if(winnerFee > 0){
            transferAmount = transferAmount.sub(winnerFee);
            _balances[winnerAddress] = _balances[winnerAddress].add(winnerFee);
            _winnerFeeTotal = _winnerFeeTotal.add(winnerFee);
            emit Transfer(account,winnerAddress,winnerFee);
        }
        if(sellinsuranceFee > 0){
            transferAmount = transferAmount.sub(sellinsuranceFee);
            _balances[insuranceAddress] = _balances[insuranceAddress].add(sellinsuranceFee);
            _sellinsuranceFeeTotal = _sellinsuranceFeeTotal.add(sellinsuranceFee);
            emit Transfer(account,insuranceAddress,sellinsuranceFee);
        }
        if(selltreasuryFee > 0){
            transferAmount = transferAmount.sub(selltreasuryFee);
            _balances[treasuryAddress] = _balances[treasuryAddress].add(selltreasuryFee);
            _selltreasuryFeeTotal = _selltreasuryFeeTotal.add(selltreasuryFee);
            emit Transfer(account,treasuryAddress,selltreasuryFee);
        }
        if(referalFee > 0){
            transferAmount = transferAmount.sub(referalFee);
            _balances[referalAddress] = _balances[referalAddress].add(referalFee);
            _referalFeeTotal = _referalFee.add(referalFee);
            emit Transfer(account,referalAddress,referalFee);
        }
        
       
        return transferAmount;
    }


 function betweencollectFee(address account, uint256 amount) private  returns (uint256) {
        
        uint256 transferAmount = amount;
       
        uint256 _inbetweenFee = amount.mul(_inbetweenFee_).div(10000);

        if (_inbetweenFee > 0){
            transferAmount = transferAmount.sub(_inbetweenFee);
            _balances[inbetweenAddress] = _balances[inbetweenAddress].add(_inbetweenFee);
            _inbetweenFeeTotal = _inbetweenFeeTotal.add(_inbetweenFee);
            emit Transfer(account,inbetweenAddress,_inbetweenFee);
        }
       
        return transferAmount;
    }

    
    function addInBlackList(address account, bool) public onlyOwner {
        blackListed[account] = true;
    }
    
    function removeFromBlackList(address account, bool) public onlyOwner {
        blackListed[account] = false;
    }

    function isBlackListed(address _address) public view returns( bool _blacklisted){
        
        if(blackListed[_address] == true){
            return true;
        }
        else{
            return false;
        }
    }

    function addInWhiteList(address account, bool) public onlyOwner {
        whiteListed[account] = true;
    }

    function removeFromWhiteList(address account, bool) public onlyOwner {
        whiteListed[account] = false;
    }

    function isWhiteListed(address _address) public view returns( bool _whitelisted){
        
        if(whiteListed[_address] == true){
            return true;
        }
        else{
            return false;
        }
    }
   
    function ExcludedFromFee(address account, bool) public onlyOwner {
        isExcludedFromFee[account] = true;
    }
    
    function IncludeInFee(address account, bool) public onlyOwner {
        isExcludedFromFee[account] = false;
    }
     
    function setWinnerFee(uint256 fee) public onlyOwner {
        _winnerFee = fee;
    }
    
    function setarenaFee(uint256 fee) public onlyOwner {
        _arenaFee = fee;
    }
    
     function setBurningFee(uint256 fee) public onlyOwner {
        _burningFee = fee;
    }
    
     function setlpFee(uint256 fee) public onlyOwner {
        _lpFee = fee;
    }
    function setinsuranceFee(uint256 fee) public onlyOwner {
        _insuranceFee = fee;
    }
    function settreasuryFee(uint256 fee) public onlyOwner {
        _treasuryFee = fee;
    }
    function setselltreasuryFee(uint256 fee) public onlyOwner {
        _selltreasuryFee = fee;
    }
    function setsellinsuranceFee(uint256 fee) public onlyOwner {
        _sellinsuranceFee = fee;
    }
     function inbetweenFee(uint256 fee) public onlyOwner {
        _inbetweenFee_ = fee;
    }
    function setArenaAddress(address _Address) public onlyOwner {
        require(_Address != arenaAddress);
        
        arenaAddress = _Address;
    }
    function setinbetweenAddress(address _Address) public onlyOwner {
        require(_Address != inbetweenAddress);
        
        inbetweenAddress = _Address;
    }

    
    function setWinnerAddress(address _Address) public onlyOwner {
        require(_Address != winnerAddress);
        
        winnerAddress = _Address;
    }
    
    function setBurningAddress(address _Address) public onlyOwner {
        require(_Address != burningAddress);
        
        burningAddress = _Address;
    }
    
     function setLPAddress(address _Address) public onlyOwner {
        require(_Address != lpAddress);
        
        lpAddress = _Address;
    }
    function setInsuranceAddress(address _Address) public onlyOwner {
        require(_Address != insuranceAddress);
        
        insuranceAddress = _Address;
    }
    
    function settreasuryAddress(address _Address) public onlyOwner {
        require(_Address != treasuryAddress);
        
        treasuryAddress = _Address;
    }
     
    function setReferalAddress(address _Address) public onlyOwner {
        require(_Address != referalAddress);
        
        referalAddress = _Address;
    }

    // function to allow admin to transfer ETH from this contract
    function TransferETH(address payable recipient, uint256 amount) public onlyOwner {
        recipient.transfer(amount);
    }
    
    modifier onlyOwner {
        require(msg.sender == contractOwner, "Only owner can call this function.");
        _;
    }
    
    
    receive() external payable {}
}
