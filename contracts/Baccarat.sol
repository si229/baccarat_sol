// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Baccarat {
    using SafeERC20 for IERC20;

    uint8 public constant ETH_TOKEN = 0;
    uint8 public constant PEPE_TOKEN = 1;
    uint8 public constant USDT_TOKEN = 2;
    uint8 public constant TOKEN_COUNT = 3;

    address public owner;
    uint64 public roundId;

    address[TOKEN_COUNT] private _tokens;
    int256[TOKEN_COUNT] private _prizePools;

    mapping(address => mapping(uint8 => int256)) private _balances;
    mapping(address => mapping(uint8 => bool)) private _hasUnsettledBet;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoundChanged(uint64 indexed roundId);

    event Deposit(address indexed player, uint8 indexed token, uint256 amount, int256 balance);
    event Withdraw(address indexed player, uint8 indexed token, uint256 amount, int256 balance);
    event BetPlaced(address indexed player, uint8 indexed token, int256 balance);
    event Settle(address indexed player, uint8 indexed token, int256 amount, int256 balance);

    event DepositPrize(address indexed player, uint8 indexed token, uint256 amount, int256 balance);
    event WithdrawPrize(address indexed player, uint8 indexed token, uint256 amount, int256 balance);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier validToken(uint8 token) {
        require(token < TOKEN_COUNT, "Invalid token index");
        _;
    }

    constructor(address pepeToken, address usdtToken) {
        require(pepeToken != address(0), "Invalid PEPE token");
        require(usdtToken != address(0), "Invalid USDT token");

        owner = msg.sender;
        _tokens[ETH_TOKEN] = address(0);
        _tokens[PEPE_TOKEN] = pepeToken;
        _tokens[USDT_TOKEN] = usdtToken;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    receive() external payable {
        _depositNativePrizePool(msg.sender, msg.value);
    }

    fallback() external payable {
        _depositNativePrizePool(msg.sender, msg.value);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setRoundId(uint64 newRoundId) external onlyOwner {
        roundId = newRoundId;
        emit RoundChanged(newRoundId);
    }

    function isOwner() external view returns (bool) {
        return msg.sender == owner;
    }

    function getToken(uint8 token) external view validToken(token) returns (address) {
        return _tokens[token];
    }

    function getPrizePool(uint8 token) external view onlyOwner validToken(token) returns (int256) {
        return _prizePools[token];
    }

    function getBalance(uint8 token) external view validToken(token) returns (int256) {
        return _balances[msg.sender][token];
    }

    function hasUnsettledBet(address player, uint8 token) external view validToken(token) returns (bool) {
        return _hasUnsettledBet[player][token];
    }

    function bet(uint8 token) external validToken(token) {
        int256 balance = _balances[msg.sender][token];
        require(balance > 0, "Insufficient balance");

        _hasUnsettledBet[msg.sender][token] = true;
        emit BetPlaced(msg.sender, token, balance);
    }

    function deposit(uint8 token, uint256 amount) external payable validToken(token) {
        require(amount > 0, "Invalid amount");

        if (token == ETH_TOKEN) {
            require(msg.value == amount, "Invalid ETH amount");
        } else {
            require(msg.value == 0, "ETH not accepted");
            _transferTokenIn(token, amount);
        }

        _balances[msg.sender][token] += int256(amount);
        emit Deposit(msg.sender, token, amount, _balances[msg.sender][token]);
    }

    function withdraw(uint8 token, uint256 amount) external validToken(token) {
        require(amount > 0, "Invalid amount");
        require(!_hasUnsettledBet[msg.sender][token], "Please settle first before proceeding");
        require(_balances[msg.sender][token] >= int256(amount), "Insufficient balance");

        _balances[msg.sender][token] -= int256(amount);
        _transferOut(msg.sender, token, amount);

        emit Withdraw(msg.sender, token, amount, _balances[msg.sender][token]);
    }

    function depositPrizePool(uint8 token, uint256 amount) external payable validToken(token) {
        require(amount > 0, "Invalid amount");

        if (token == ETH_TOKEN) {
            require(msg.value == amount, "Invalid ETH amount");
        } else {
            require(msg.value == 0, "ETH not accepted");
            _transferTokenIn(token, amount);
        }

        _prizePools[token] += int256(amount);
        emit DepositPrize(msg.sender, token, amount, _prizePools[token]);
    }

    function withdrawPrizePool(uint8 token, uint256 amount) external onlyOwner validToken(token) {
        require(amount > 0, "Invalid amount");
        require(_prizePools[token] >= int256(amount), "Insufficient balance");

        _prizePools[token] -= int256(amount);
        _transferOut(msg.sender, token, amount);

        emit WithdrawPrize(msg.sender, token, amount, _prizePools[token]);
    }

    function deposit(uint8 token, uint256 amount) external payable validToken(token) {
        require(amount > 0, "amount must > 0");

        if(token==0){
               _balance[msg.sender][token] += int256(msg.value);

        }else{
            (bool success, bytes memory data) = _tokens[token].call(
                        abi.encodeWithSelector(IERC20.transferFrom.selector
                        , msg.sender, address(this), amount)
                    );
            require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
             _balance[msg.sender][token] += int256(amount);
        }
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

    function _depositNativePrizePool(address player, uint256 amount) private {
        require(amount > 0, "Invalid amount");

        _prizePools[ETH_TOKEN] += int256(amount);
        emit DepositPrize(player, ETH_TOKEN, amount, _prizePools[ETH_TOKEN]);
    }

    function _transferTokenIn(uint8 token, uint256 amount) private {
        IERC20(_tokens[token]).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _transferOut(address to, uint8 token, uint256 amount) private {
        if (token == ETH_TOKEN) {
            (bool success, ) = payable(to).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(_tokens[token]).safeTransfer(to, amount);
        }
    }
}
