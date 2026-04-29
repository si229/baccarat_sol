// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Baccarat {

    address private owner;
    mapping(address=>uint256) private playerBalances;
    mapping(address=>bool) private betState;
    bytes32 public resultSha256;
    uint64 public roundId;
    uint256 private prizePool;


    event Deposit(address player, uint256 amount,uint256 balance);
    event Withdraw(address player, uint256 amount,uint256 contract_balance ,uint256 wallet_balance);
    event Settle(address player, int256 amount,uint256 balance);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor() {
        owner = msg.sender; 
    }

    function setRoundId(uint64 ID) external   {
        roundId = ID;
    }

    function bet() external {
        if (playerBalances[msg.sender] != 0){
            betState[msg.sender] = true;
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function isOwner()  external view returns(bool) {
        return msg.sender == owner;
    }

    function checkBetValid(address[] memory roles) external view onlyOwner returns (bool[] memory){
        bool[] memory check = new bool[](roles.length);
        for(uint i=0;i<roles.length;i++){
            check[i] = betState[roles[i]];
        }
        return check;
    }

    function setResultHash(bytes32 result) external  {
        resultSha256 = result;
    }

    function getPrizePool() external view onlyOwner returns (uint256) {
        return prizePool;
    }

    function getBalance() external view returns (uint256){
        return playerBalances[msg.sender];
    }

    function depositPrizePool() external payable {
            prizePool+=msg.value;
    }

   
    function withdrawPrizePool(uint256 amount) external onlyOwner {
        require(prizePool >= amount, "Insufficient balance");
        prizePool -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function deposit() external payable {
        require(0 < msg.value, "AMOUNT must be greater than 0 ");
        playerBalances[msg.sender]+=msg.value;
        emit Deposit(msg.sender,msg.value,playerBalances[msg.sender]);
        
        }
    
    function withdraw(uint256 amount) external payable {
            require(playerBalances[msg.sender] >= amount, "Insufficient balance");
            require(0 < amount, "AMOUNT must be greater than 0 ");
            require(betState[msg.sender] == true, "Please settle first before proceeding");
            playerBalances[msg.sender]-=amount;
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Transfer failed");
            emit Withdraw(msg.sender,amount,playerBalances[msg.sender],msg.sender.balance);
    }


   function settle(address player,uint256 SettleAmount,bool isLoss ) external onlyOwner {
        if (isLoss){
            if (playerBalances[player]<=SettleAmount){
                delete playerBalances[player];
            }else{
                playerBalances[player] -= SettleAmount;
            }
            prizePool+=SettleAmount;
        }else{
          playerBalances[player] += SettleAmount;
          if (prizePool<=SettleAmount){
            prizePool = 0;
          }else{
            prizePool-=SettleAmount;
          }

        }

        betState[player] = true;
       
    }


    receive() external payable { 
        prizePool+=msg.value;
        emit  Deposit(msg.sender, msg.value,prizePool);

    }

    fallback() external payable {
        prizePool+=msg.value;
        emit  Deposit(msg.sender, msg.value,prizePool);
     }

} 
