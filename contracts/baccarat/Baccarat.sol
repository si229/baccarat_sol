// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBaccarat.sol";

contract Baccarat is Ownable, IBaccarat {
    using SafeERC20 for IERC20;

    uint8 private constant TOKEN_COUNT = 3;

    uint64 public roundId;

    TokenConfig[TOKEN_COUNT] private _tokens;
    uint256[TOKEN_COUNT] private _prizePools;
    mapping(address => mapping(uint8 => PlayerPosition)) private _positions;

    constructor(address pepeToken, address usdtToken) {
        if (pepeToken == address(0)) revert("Invalid PEPE token");
        if (usdtToken == address(0)) revert("Invalid USDT token");

        _tokens[uint8(TokenKind.Native)] = TokenConfig({asset: address(0), symbol: "ETH"});
        _tokens[uint8(TokenKind.Pepe)] = TokenConfig({asset: pepeToken, symbol: "PEPE"});
        _tokens[uint8(TokenKind.Usdt)] = TokenConfig({asset: usdtToken, symbol: "USDT"});
    }

    receive() external payable {
        revert("Use deposit function");
    }

    fallback() external payable {
        revert("Use deposit function");
    }

    function setRoundId(uint64 newRoundId) external onlyOwner {
        roundId = newRoundId;
        emit RoundChanged(newRoundId);
    }

    function tokenAddress(TokenKind token) external view returns (address) {
        return _tokens[_tokenIndex(token)].asset;
    }

    function prizePoolBalance(TokenKind token) external view returns (uint256) {
        return _prizePools[_tokenIndex(token)];
    }

    function playerBalance(address player, TokenKind token) external view returns (uint256) {
        return _positions[player][_tokenIndex(token)].balance;
    }

    function playerUnsettledBalance(address player, TokenKind token) external view returns (uint256) {
        return _positions[player][_tokenIndex(token)].unsettledBalance;
    }

    function playerPosition(address player, TokenKind token) external view returns (PlayerPosition memory) {
        return _positions[player][_tokenIndex(token)];
    }

    function hasOpenBet(address player, TokenKind token) external view returns (bool) {
        PlayerPosition storage position = _positions[player][_tokenIndex(token)];
        return position.hasOpenBet || position.unsettledBalance > 0;
    }

    function depositPlayerBalance(TokenKind token, uint256 amount) external payable {
        _depositPlayerBalance(token, amount);
    }

    function setPlayerUnsettledBalance(address player, TokenKind token, uint256 unsettledBalance) external onlyOwner {
        _setPlayerUnsettledBalance(player, token, unsettledBalance);
    }

    function withdrawPlayerBalance(TokenKind token, uint256 amount) external {
        _withdrawPlayerBalance(token, amount);
    }

    function fundPrizePool(TokenKind token, uint256 amount) external payable {
        _fundPrizePool(token, amount);
    }

    function withdrawPrizePool(TokenKind token, uint256 amount) external onlyOwner {
        uint8 tokenId = _tokenIndex(token);
        if (amount == 0) revert("Invalid amount");
        if (_prizePools[tokenId] < amount) revert("Insufficient prize pool");

        _prizePools[tokenId] -= amount;
        _sendFunds(msg.sender, tokenId, amount);

        emit PrizePoolWithdrawal(msg.sender, token, amount, _prizePools[tokenId]);
    }

    function placeBet(TokenKind token) external {
        _placeBet(token);
    }

    function settleBet(address player, TokenKind token, int256 payout) external onlyOwner {
        uint8 tokenId = _tokenIndex(token);
        PlayerPosition storage position = _positions[player][tokenId];

        if (!position.hasOpenBet) revert("No open bet");
        position.hasOpenBet = false;
        position.unsettledBalance = 0;

        if (payout > 0) {
            uint256 winAmount = uint256(payout);
            if (_prizePools[tokenId] < winAmount) revert("Insufficient prize pool");

            _prizePools[tokenId] -= winAmount;
            position.balance += winAmount;
        } else if (payout < 0) {
            uint256 lossAmount = uint256(-payout);
            if (position.balance < lossAmount) revert("Insufficient player balance");

            position.balance -= lossAmount;
            _prizePools[tokenId] += lossAmount;
        }

        emit BetSettled(player, token, payout, position.balance);
    }

    function isOwner() external view returns (bool) {
        return msg.sender == owner();
    }

    function getToken(uint8 token) external view returns (address) {
        return _tokens[_legacyTokenIndex(token)].asset;
    }

    function getPrizePool(uint8 token) external view returns (uint256) {
        return _prizePools[_legacyTokenIndex(token)];
    }

    function getBalance(uint8 token) external view returns (uint256) {
        return _positions[msg.sender][_legacyTokenIndex(token)].balance;
    }

    function hasUnsettledBet(address player, uint8 token) external view returns (bool) {
        PlayerPosition storage position = _positions[player][_legacyTokenIndex(token)];
        return position.hasOpenBet || position.unsettledBalance > 0;
    }

    function getUnsettledBalance(address player, uint8 token) external view returns (uint256) {
        return _positions[player][_legacyTokenIndex(token)].unsettledBalance;
    }

    function deposit(uint8 token, uint256 amount) external payable {
        _depositPlayerBalance(_legacyTokenKind(token), amount);
    }

    function withdraw(uint8 token, uint256 amount) external {
        _withdrawPlayerBalance(_legacyTokenKind(token), amount);
    }

    function setUnsettledBalance(address player, uint8 token, uint256 unsettledBalance) external onlyOwner {
        _setPlayerUnsettledBalance(player, _legacyTokenKind(token), unsettledBalance);
    }

    function depositPrizePool(uint8 token, uint256 amount) external payable {
        _fundPrizePool(_legacyTokenKind(token), amount);
    }

    function bet(uint8 token) external {
        _placeBet(_legacyTokenKind(token));
    }

    function _increasePrizePool(TokenKind token, uint8 tokenId, uint256 amount, address funder) private {
        _prizePools[tokenId] += amount;
        emit PrizePoolFunded(funder, token, amount, _prizePools[tokenId]);
    }

    function _receiveFunds(uint8 tokenId, uint256 amount) private {
        if (amount == 0) revert("Invalid amount");

        if (tokenId == uint8(TokenKind.Native)) {
            if (msg.value != amount) revert("Invalid native amount");
            return;
        }

        if (msg.value != 0) revert("Native token not accepted");
        IERC20(_tokens[tokenId].asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _sendFunds(address to, uint8 tokenId, uint256 amount) private {
        if (tokenId == uint8(TokenKind.Native)) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert("Native transfer failed");
            return;
        }

        IERC20(_tokens[tokenId].asset).safeTransfer(to, amount);
    }

    function _tokenIndex(TokenKind token) private pure returns (uint8) {
        uint8 tokenId = uint8(token);
        if (tokenId >= TOKEN_COUNT) revert("Invalid token");
        return tokenId;
    }

    function _depositPlayerBalance(TokenKind token, uint256 amount) private {
        uint8 tokenId = _tokenIndex(token);
        _receiveFunds(tokenId, amount);

        PlayerPosition storage position = _positions[msg.sender][tokenId];
        position.balance += amount;

        emit PlayerDeposit(msg.sender, token, amount, position.balance);
    }

    function _withdrawPlayerBalance(TokenKind token, uint256 amount) private {
        uint8 tokenId = _tokenIndex(token);
        if (amount == 0) revert("Invalid amount");

        PlayerPosition storage position = _positions[msg.sender][tokenId];
        if (position.hasOpenBet || position.unsettledBalance > 0) revert("Settle bet first");
        if (position.balance < amount) revert("Insufficient balance");

        position.balance -= amount;
        _sendFunds(msg.sender, tokenId, amount);

        emit PlayerWithdrawal(msg.sender, token, amount, position.balance);
    }

    function _fundPrizePool(TokenKind token, uint256 amount) private {
        uint8 tokenId = _tokenIndex(token);
        _receiveFunds(tokenId, amount);
        _increasePrizePool(token, tokenId, amount, msg.sender);
    }

    function _placeBet(TokenKind token) private {
        uint8 tokenId = _tokenIndex(token);
        PlayerPosition storage position = _positions[msg.sender][tokenId];

        if (position.balance == 0) revert("Insufficient balance");
        if (position.hasOpenBet) revert("Bet already open");

        position.hasOpenBet = true;
        position.unsettledBalance = position.balance;
        emit BetPlaced(msg.sender, token, roundId, position.balance);
    }

    function _setPlayerUnsettledBalance(address player, TokenKind token, uint256 unsettledBalance) private {
        if (player == address(0)) revert("Invalid player");

        uint8 tokenId = _tokenIndex(token);
        PlayerPosition storage position = _positions[player][tokenId];
        if (unsettledBalance > position.balance) revert("Insufficient player balance");

        position.unsettledBalance = unsettledBalance;
        position.hasOpenBet = unsettledBalance > 0;

        emit PlayerUnsettledBalanceUpdated(player, token, unsettledBalance);
    }

    function _legacyTokenKind(uint8 token) private pure returns (TokenKind) {
        return TokenKind(_legacyTokenIndex(token));
    }

    function _legacyTokenIndex(uint8 token) private pure returns (uint8) {
        if (token >= TOKEN_COUNT) revert("Invalid token");
        return token;
    }
}
