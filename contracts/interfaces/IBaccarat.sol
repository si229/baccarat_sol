// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IBaccarat {
    enum TokenKind {
        Native,
        Pepe,
        Usdt
    }

    struct TokenConfig {
        address asset;
        string symbol;
    }

    struct AmountLimits {
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 maxWithdraw;
    }

    event RoundChanged(uint64 indexed roundId);
    event PlayerDeposit(address indexed player, TokenKind indexed token, uint256 amount, uint256 balance);
    event PlayerWithdrawal(address indexed player, TokenKind indexed token, uint256 amount, uint256 balance);
    event PlayerWithdrawalLockUpdated(address indexed player, bool locked);
    event TokenAmountLimitsUpdated(
        TokenKind indexed token,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 maxWithdraw
    );
    event BetPlaced(address indexed player, TokenKind indexed token, uint64 indexed roundId, uint256 balance);
    event BetSettled(address indexed player, TokenKind indexed token, int256 payout, uint256 balance);
    event PrizePoolFunded(address indexed funder, TokenKind indexed token, uint256 amount, uint256 balance);
    event PrizePoolWithdrawal(address indexed operator, TokenKind indexed token, uint256 amount, uint256 balance);

    function tokenAddress(TokenKind token) external view returns (address);
    function prizePoolBalance(TokenKind token) external view returns (uint256);
    function playerBalance(address player, TokenKind token) external view returns (uint256);
    function isWithdrawalLocked(address player) external view returns (bool);
    function amountLimits(TokenKind token) external view returns (AmountLimits memory);

    function setRoundId(uint64 newRoundId) external;
    function setPlayerWithdrawalLocked(address player) external;
    function setPlayerWithdrawalUnlocked(address player) external;
    function setAmountLimits(
        TokenKind token,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 maxWithdraw
    ) external;
    function depositPlayerBalance(TokenKind token, uint256 amount) external payable;
    function withdrawPlayerBalance(TokenKind token, uint256 amount) external;
    function fundPrizePool(TokenKind token, uint256 amount) external payable;
    function withdrawPrizePool(TokenKind token, uint256 amount) external;
    function placeBet(TokenKind token) external;
    function settleBet(address player, TokenKind token, int256 payout) external;

    function isOwner() external view returns (bool);
    function getToken(uint8 token) external view returns (address);
    function getPrizePool(uint8 token) external view returns (uint256);
    function getBalance(uint8 token) external view returns (uint256);
    function setWithdrawalLocked(address player) external;
    function setWithdrawalUnlocked(address player) external;
    function deposit(uint8 token, uint256 amount) external payable;
    function withdraw(uint8 token, uint256 amount) external;
    function depositPrizePool(uint8 token, uint256 amount) external payable;
    function bet(uint8 token) external;
}
