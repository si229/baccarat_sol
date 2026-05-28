// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBaccarat.sol";

contract Baccarat is Ownable, IBaccarat {
    using SafeERC20 for IERC20;

    uint8 private constant TOKEN_COUNT = 3;
    string private constant CONTRACT_VERSION = "baccarat-2026-05-28.1";

    uint64 public roundId;

    TokenConfig[TOKEN_COUNT] private _tokens;
    AmountLimits[TOKEN_COUNT] private _limits;
    uint256[TOKEN_COUNT] private _prizePools;
    mapping(address => mapping(uint8 => uint256)) private _balances;
    mapping(address => bool) private _withdrawalLocks;

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
        return _balances[player][_tokenIndex(token)];
    }

    function isWithdrawalLocked(address player) external view returns (bool) {
        return _withdrawalLocks[player];
    }

    function amountLimits(TokenKind token) external view returns (AmountLimits memory) {
        return _limits[_tokenIndex(token)];
    }

    function contractVersion() external pure returns (string memory) {
        return CONTRACT_VERSION;
    }

    function depositPlayerBalance(TokenKind token, uint256 amount) external payable {
        _depositPlayerBalance(token, amount);
    }

    function setPlayerWithdrawalLocked(address player) external onlyOwner {
        _setPlayerWithdrawalLock(player, true);
    }

    function setPlayerWithdrawalUnlocked(address player) external onlyOwner {
        _setPlayerWithdrawalLock(player, false);
    }

    function setAmountLimits(
        TokenKind token,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 maxWithdraw
    ) external onlyOwner {
        if (maxDeposit != 0 && minDeposit > maxDeposit) revert("Invalid deposit limits");

        uint8 tokenId = _tokenIndex(token);
        _limits[tokenId] = AmountLimits({
            minDeposit: minDeposit,
            maxDeposit: maxDeposit,
            maxWithdraw: maxWithdraw
        });

        emit TokenAmountLimitsUpdated(token, minDeposit, maxDeposit, maxWithdraw);
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

    function settlePlayerBalance(address player, TokenKind token, int256 delta) external onlyOwner {
        _settlePlayerBalance(player, token, delta);
    }

    function settlePlayerBalances(
        address player,
        TokenKind[] calldata tokens,
        int256[] calldata deltas
    ) external onlyOwner {
        if (tokens.length != deltas.length) revert("Settlement length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            if (deltas[i] != 0) {
                _settlePlayerBalance(player, tokens[i], deltas[i]);
            }
        }
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
        return _balances[msg.sender][_legacyTokenIndex(token)];
    }

    function deposit(uint8 token, uint256 amount) external payable {
        _depositPlayerBalance(_legacyTokenKind(token), amount);
    }

    function withdraw(uint8 token, uint256 amount) external {
        _withdrawPlayerBalance(_legacyTokenKind(token), amount);
    }

    function setWithdrawalLocked(address player) external onlyOwner {
        _setPlayerWithdrawalLock(player, true);
    }

    function setWithdrawalUnlocked(address player) external onlyOwner {
        _setPlayerWithdrawalLock(player, false);
    }

    function depositPrizePool(uint8 token, uint256 amount) external payable {
        _fundPrizePool(_legacyTokenKind(token), amount);
    }

    function bet(uint8 token) external {
        _placeBet(_legacyTokenKind(token));
    }

    function _settlePlayerBalance(address player, TokenKind token, int256 delta) private {
        uint8 tokenId = _tokenIndex(token);
        if (delta > 0) {
            uint256 winAmount = uint256(delta);
            if (_prizePools[tokenId] < winAmount) revert("Insufficient prize pool");

            _prizePools[tokenId] -= winAmount;
            _balances[player][tokenId] += winAmount;
        } else if (delta < 0) {
            uint256 lossAmount = uint256(-delta);
            if (_balances[player][tokenId] < lossAmount) revert("Insufficient player balance");

            _balances[player][tokenId] -= lossAmount;
            _prizePools[tokenId] += lossAmount;
        }

        emit PlayerBalanceSettled(player, token, delta, _balances[player][tokenId]);
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
        _validateAmount(amount, _limits[tokenId].minDeposit, _limits[tokenId].maxDeposit);
        _receiveFunds(tokenId, amount);

        _balances[msg.sender][tokenId] += amount;

        emit PlayerDeposit(msg.sender, token, amount, _balances[msg.sender][tokenId]);
    }

    function _withdrawPlayerBalance(TokenKind token, uint256 amount) private {
        uint8 tokenId = _tokenIndex(token);
        if (amount == 0) revert("Invalid amount");

        if (_withdrawalLocks[msg.sender]) revert("Withdraw locked");
        _validateMaxAmount(amount, _limits[tokenId].maxWithdraw);
        if (_balances[msg.sender][tokenId] < amount) revert("Insufficient balance");

        _balances[msg.sender][tokenId] -= amount;
        _sendFunds(msg.sender, tokenId, amount);

        emit PlayerWithdrawal(msg.sender, token, amount, _balances[msg.sender][tokenId]);
    }

    function _fundPrizePool(TokenKind token, uint256 amount) private {
        uint8 tokenId = _tokenIndex(token);
        _receiveFunds(tokenId, amount);
        _increasePrizePool(token, tokenId, amount, msg.sender);
    }

    function _placeBet(TokenKind token) private {
        uint8 tokenId = _tokenIndex(token);
        if (_balances[msg.sender][tokenId] == 0) revert("Insufficient balance");
        emit BetPlaced(msg.sender, token, roundId, _balances[msg.sender][tokenId]);
    }

    function _setPlayerWithdrawalLock(address player, bool locked) private {
        if (player == address(0)) revert("Invalid player");

        _withdrawalLocks[player] = locked;

        emit PlayerWithdrawalLockUpdated(player, locked);
    }

    function _validateAmount(uint256 amount, uint256 minAmount, uint256 maxAmount) private pure {
        if (amount == 0) revert("Invalid amount");
        if (minAmount != 0 && amount < minAmount) revert("Amount below minimum");
        if (maxAmount != 0 && amount > maxAmount) revert("Amount above maximum");
    }

    function _validateMaxAmount(uint256 amount, uint256 maxAmount) private pure {
        if (maxAmount != 0 && amount > maxAmount) revert("Amount above maximum");
    }

    function _legacyTokenKind(uint8 token) private pure returns (TokenKind) {
        return TokenKind(_legacyTokenIndex(token));
    }

    function _legacyTokenIndex(uint8 token) private pure returns (uint8) {
        if (token >= TOKEN_COUNT) revert("Invalid token");
        return token;
    }
}
