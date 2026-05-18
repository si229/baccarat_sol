// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Baccarat {

    address private _owner;
    mapping(address => mapping(uint8 => int256)) internal _balance;
    mapping(address => mapping(uint8 => bool)) internal _betState;


     address[3] private _tokens = [
        0x0000000000000000000000000000000000000000, // ETH
        0x948B3c65b89DF0B4894ABE91E6D02FE579834F8F,  // PEPE
        0x8464135c8F25Da09e49BC8782676a84730C318bC  // USDT
    ];

    uint64 public roundId;
    int256[3] private _prizePool;

    event Deposit(address indexed player,uint8 indexed token, uint256 amount,int256 balance);
    event Withdraw(address indexed player,uint8 indexed token,  uint256 amount,int256 balance);
    event Settle(address indexed player, uint8 indexed token,int256 amount,int256 balance);

    event DepositPrize(address indexed player, uint8 indexed token,int256 amount,int256 balance);
    event WithdrawPrize(address indexed player, uint8 indexed token,int256 amount,int256 balance);


    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not owner");
        _;
    }


    modifier validToken(uint8 token) {
        require(token <= 2, "Invalid token index");
        _;
    }

    constructor() {
        _owner = msg.sender; 
        _tokens[0] = 0x0000000000000000000000000000000000000000; // ETH
        _tokens[1] = 0x948B3c65b89DF0B4894ABE91E6D02FE579834F8F;  // PEPE
        _tokens[2] = 0x8464135c8F25Da09e49BC8782676a84730C318bC;  // USDT

    }

    function setRoundId(uint64 ID) external   {
        roundId = ID;
    }

    function bet(uint8 token) external validToken(token) {
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

    function getPrizePool(uint8 token) external view onlyOwner validToken(token) returns (int256) {
        return _prizePool[token];
    }


    function getBalance(uint8 token) external view returns (int256){
        return _balance[msg.sender][token];
    }


    function depositPrizePool(uint8 token, uint256 amount) external payable validToken(token) {
        (bool success, bytes memory data) = _tokens[token].call(
        abi.encodeWithSelector(IERC20.transferFrom.selector
        , msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");

        _prizePool[token] += int256(amount);
        emit DepositPrize(msg.sender, token, int256(amount), _prizePool[token]);
    }

    function withdrawPrizePool(uint8 token, uint256 amount) external onlyOwner validToken(token) {
        require(amount > 0, "invalid amount");
        require(_prizePool[token] >= int256(amount), "Insufficient balance");
        _prizePool[token] -= int256(amount);

        (bool success, bytes memory data) = _tokens[token].call(
        abi.encodeWithSelector(IERC20.transfer.selector
        , msg.sender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");

        emit WithdrawPrize(msg.sender, token, int256(amount), _prizePool[token]);
    }


    function deposit(uint8 token, uint256 amount) external payable validToken(token) {
        require(amount > 0, "amount must > 0");
        (bool success, bytes memory data) = _tokens[token].call(
            abi.encodeWithSelector(IERC20.transferFrom.selector
            , msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
        _balance[msg.sender][token] += int256(amount);
        emit Deposit(msg.sender, token, amount, _balance[msg.sender][token]);
    }


    function withdraw(uint8 token, uint256 amount) external payable validToken(token) {
        require(_balance[msg.sender][token] >= int256(amount), "Insufficient balance");
        require(_betState[msg.sender][token]==false, "Please settle first before proceeding");
        _balance[msg.sender][token] -= int256(amount);

        (bool success, bytes memory data) = _tokens[token].call(abi.encodeWithSelector(IERC20.transfer.selector, msg.sender, amount));

        require(success && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
        
        emit Withdraw(msg.sender,token, amount,_balance[msg.sender][token]);
    }


   function settle(address player,int256 SettleAmount,uint8 token) external onlyOwner validToken(token) {
       _balance[player][token]+=SettleAmount;
       _prizePool[token]-=int256(SettleAmount);

       if (_balance[player][token]<=0){
            delete _balance[player][token];
            delete  _betState[player][0];
       }else{
             _betState[player][0]   = true;
       }
    }


    receive() external payable { 
        _prizePool[0]+=int256(msg.value);
        emit  Deposit(msg.sender, 0, msg.value,_prizePool[0]);

    }

    fallback() external payable {
        _prizePool[0]+=int256(msg.value);
        emit  Deposit(msg.sender, 0, msg.value,_prizePool[0]  );
     }

} 
