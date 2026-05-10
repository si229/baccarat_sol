// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Baccarat {

    address private _owner;
    mapping(address => mapping(address => int256)) internal _balance;
    mapping(address => mapping(address => bool)) internal _betState;
    uint64 public roundId;
    mapping(address=>int256) private _prizePool;

    event Deposit(address indexed player,address indexed token, uint256 amount,int256 balance);
    event Withdraw(address indexed player,address indexed token,  uint256 amount,int256 balance);
    event Settle(address indexed player, address indexed token,int256 amount,int256 balance);

    event DepositPrize(address indexed player, address indexed token,int256 amount,int256 balance);
    event WithdrawPrize(address indexed player, address indexed token,int256 amount,int256 balance);


    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not owner");
        _;
    }

    constructor() {
        _owner = msg.sender; 
    }

    function setRoundId(uint64 ID) external   {
        roundId = ID;
    }

    function bet(address token) external {
        if (_balance[msg.sender][token] != 0){
            _betState[msg.sender][token] = true;
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
    }

    function isOwner()  external view returns(bool) {
        return msg.sender == _owner;
    }

    function getPrizePool(address token) external view onlyOwner returns (int256) {
        
        return _prizePool[token];
    }

    function getBalance() external view returns (int256){
        return _balance[msg.sender][address(0)];
    }

    function getBalance(address token) external view returns (int256){
        return _balance[msg.sender][token];
    }

    function depositPrizePool() external payable {
        if(msg.value>0){
            _prizePool[address(0)]+=int256(msg.value);
            emit DepositPrize(msg.sender, address(0), int256(msg.value), _prizePool[address(0)]);
        }
    }

    function depositPrizePool(address token, uint256 amount) external {
        (bool success, bytes memory data) = token.call(
        abi.encodeWithSelector(IERC20.transferFrom.selector
        , msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");

        _prizePool[token] += int256(amount);
        emit DepositPrize(msg.sender, token, int256(amount), _prizePool[token]);
    }
   
    function withdrawPrizePool(uint256 amount) external onlyOwner {
        require(_prizePool[address(0)] >= int256(amount), "Insufficient balance");
        _prizePool[address(0)] -= int256(amount);
        (bool success, ) = payable(msg.sender).call{value: uint256(int256(amount))}("");
        require(success, "Transfer failed");
        emit WithdrawPrize(msg.sender, address(0), int256(amount), _prizePool[address(0)]);
    }


    function withdrawPrizePool(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "invalid amount");
        require(_prizePool[token] >= int256(amount), "Insufficient balance");
        _prizePool[token] -= int256(amount);

        (bool success, bytes memory data) = token.call(
        abi.encodeWithSelector(IERC20.transfer.selector
        , msg.sender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");

        emit WithdrawPrize(msg.sender, token, int256(amount), _prizePool[token]);
    }

    function deposit() external payable {
        require(0 < msg.value, "AMOUNT must be greater than 0 ");
        _balance[msg.sender][address(0)] += int256(msg.value);
        emit Deposit(msg.sender,address(0) ,msg.value,_balance[msg.sender][address(0)]);
        }
    

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "amount must > 0");
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector
            , msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
        _balance[msg.sender][token] += int256(amount);
        emit Deposit(msg.sender, token, amount, _balance[msg.sender][token]);
    }

    function withdraw(uint256 amount) external payable {
        require(_balance[msg.sender][address(0)] >= int256(amount), "Insufficient balance");
        require(_betState[msg.sender][address(0)]==false, "Please settle first before proceeding");
        _balance[msg.sender][address(0)] -= int256(amount);
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdraw(msg.sender,address(0) ,amount,_balance[msg.sender][address(0)]);
    }

    function withdraw(address token, uint256 amount) external payable {
            require(_balance[msg.sender][token] >= int256(amount), "Insufficient balance");
            require(_betState[msg.sender][token], "Please settle first before proceeding");
            _balance[msg.sender][token] -= int256(amount);

           (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, amount));

            require(success && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
          
            emit Withdraw(msg.sender,token, amount,_balance[msg.sender][token]);
    }


   function settle(address player,int256 SettleAmount,address token) external onlyOwner {
       _balance[player][token]+=SettleAmount;
       _prizePool[token]-=int256(SettleAmount);

       if (_balance[player][token]<=0){
            delete _balance[player][token];
            delete  _betState[player][address(0)];
       }else{
             _betState[player][address(0)]   = true;
       }
    }


    receive() external payable { 
        _prizePool[address(0)]+=int256(msg.value);
        emit  Deposit(msg.sender, address(0), msg.value,_prizePool[address(0)]);

    }

    fallback() external payable {
        _prizePool[address(0)]+=int256(msg.value);
        emit  Deposit(msg.sender, address(0), msg.value,_prizePool[address(0)]  );
     }

} 
