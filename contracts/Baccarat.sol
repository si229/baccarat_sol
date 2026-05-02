// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Baccarat {

    address private _owner;
    mapping(address => mapping(address => int256)) internal _balance;
    mapping(address => mapping(address => bool)) internal _betState;
    bytes32 public resultSha256;
    uint64 public roundId;
    mapping(address=>int256) private _prizePool;

    event Deposit(address indexed player,address indexed token, uint256 amount,int256 balance);
    event Withdraw(address indexed player,address indexed token,  uint256 amount,int256 balance);
    event Settle(address indexed player, address indexed token,int256 amount,int256 balance);

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
            _prizePool[address(0)]+=int256(msg.value);
    }

   
    function withdrawPrizePool(uint256 amount) external onlyOwner {
        require(_prizePool[address(0)] >= int256(amount), "Insufficient balance");
        _prizePool[address(0)] -= int256(amount);
        (bool success, ) = payable(msg.sender).call{value: uint256(int256(amount))}("");
        require(success, "Transfer failed");
    }


    function withdrawPrizePool(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "invalid amount");
        require(_prizePool[token] >= int256(amount), "Insufficient balance");
        _prizePool[token] -= int256(amount);
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "Transfer failed");
    }

    function deposit() external payable {
        require(0 < msg.value, "AMOUNT must be greater than 0 ");
        _balance[msg.sender][address(0)] += int256(msg.value);
        emit Deposit(msg.sender,address(0) ,msg.value,_balance[msg.sender][address(0)]);
        }
    

    function deposit(address token, uint amount) external {
        require(amount > 0, "zero amount");

        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "transfer failed");
        _balance[msg.sender][token] += int256(amount);
        emit Deposit(msg.sender,token, amount,_balance[msg.sender][token]);
    }

    function withdraw(uint256 amount) external payable {
            require(_balance[msg.sender][address(0)] >= int256(amount), "Insufficient balance");
            require(0 < amount, "AMOUNT must be greater than 0 ");
            require(_betState[msg.sender][address(0)] == true, "Please settle first before proceeding");
            _balance[msg.sender][address(0)] -= int256(amount);
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Transfer failed");
            emit Withdraw(msg.sender,address(0) ,amount,_balance[msg.sender][address(0)]);
    }

    function withdraw(address token, uint256 amount) external payable {
            require(_balance[msg.sender][token] >= int256(amount), "Insufficient balance");
            require(0 < amount, "AMOUNT must be greater than 0 ");
            require(_betState[msg.sender][token] == true, "Please settle first before proceeding");
            _balance[msg.sender][token] -= int256(amount);
            bool success = IERC20(token).transfer(msg.sender, amount);
            require(success, "Transfer failed");
            emit Withdraw(msg.sender,token, amount,_balance[msg.sender][token]);
    }


   function settle(address player,uint256 SettleAmount,bool isLoss ) external onlyOwner {
        if (isLoss){
            if (_balance[player][address(0)] <= int256(SettleAmount)){
                delete _balance[player][address(0)];
            }else{
                _balance[player][address(0)] -= int256(SettleAmount);
            }
            _prizePool[address(0)]+=int256(SettleAmount);
        }else{
          _balance[player][address(0)] += int256(SettleAmount);
          if (_prizePool[address(0)]<=int256(SettleAmount)){
            _prizePool[address(0)] = 0;
          }else{
            _prizePool[address(0)]-=int256(SettleAmount);
          }

        }

        _betState[player][address(0)]   = true;
       
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
