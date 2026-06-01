(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.BaccaratSim = factory();
  }
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  const ZONES = {
    banker: { label: "Banker", odds: 0.95 },
    player: { label: "Player", odds: 1 },
    tie: { label: "Tie", odds: 8 },
    bankerPair: { label: "Banker Pair", odds: 11 },
    playerPair: { label: "Player Pair", odds: 11 },
  };

  const DEFAULT_MIX = {
    banker: 45,
    player: 40,
    tie: 5,
    bankerPair: 5,
    playerPair: 5,
  };

  function createRng(seed) {
    let state = hashSeed(String(seed || Date.now()));
    return function rng() {
      state = (state + 0x6d2b79f5) | 0;
      let value = Math.imul(state ^ (state >>> 15), 1 | state);
      value ^= value + Math.imul(value ^ (value >>> 7), 61 | value);
      return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    };
  }

  function hashSeed(seed) {
    let hash = 2166136261;
    for (let i = 0; i < seed.length; i += 1) {
      hash ^= seed.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  function createShoe(rng, decks) {
    const cards = [];
    for (let deck = 0; deck < decks; deck += 1) {
      for (let suit = 1; suit <= 4; suit += 1) {
        for (let rank = 1; rank <= 13; rank += 1) {
          cards.push({ rank, suit });
        }
      }
    }
    for (let i = cards.length - 1; i > 0; i -= 1) {
      const j = Math.floor(rng() * (i + 1));
      const tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
    return cards;
  }

  function point(cards) {
    return cards.reduce((sum, card) => sum + (card.rank <= 9 ? card.rank : 0), 0) % 10;
  }

  function dealRound(state) {
    if (state.shoe.length <= state.cutCard) {
      state.shoe = createShoe(state.rng, state.decks);
      state.shoes += 1;
    }

    const player = [state.shoe.pop(), state.shoe.pop()];
    const banker = [state.shoe.pop(), state.shoe.pop()];
    const playerPoint = point(player);
    const bankerPoint = point(banker);

    if (playerPoint >= 8 || bankerPoint >= 8) {
      return finishRound(player, banker);
    }

    let playerDrawPoint = point([player[1]]);
    let playerDrew = false;
    if (playerPoint < 6) {
      const card = state.shoe.pop();
      player.push(card);
      playerDrawPoint = point([card]);
      playerDrew = true;
    }

    if (bankerPoint === 7) {
      return finishRound(player, banker);
    }
    if (bankerPoint === 6) {
      if (playerDrew && (playerDrawPoint === 6 || playerDrawPoint === 7)) banker.push(state.shoe.pop());
      return finishRound(player, banker);
    }
    if (bankerPoint === 5) {
      if (!(playerDrew && [0, 1, 2, 3, 8, 9].includes(playerDrawPoint))) banker.push(state.shoe.pop());
      return finishRound(player, banker);
    }
    if (bankerPoint === 4) {
      if (!(playerDrew && [0, 1, 8, 9].includes(playerDrawPoint))) banker.push(state.shoe.pop());
      return finishRound(player, banker);
    }
    if (bankerPoint === 3) {
      if (!(playerDrew && playerDrawPoint === 8)) banker.push(state.shoe.pop());
      return finishRound(player, banker);
    }
    banker.push(state.shoe.pop());
    return finishRound(player, banker);
  }

  function finishRound(player, banker) {
    const playerPoint = point(player);
    const bankerPoint = point(banker);
    const winner = playerPoint === bankerPoint ? "tie" : playerPoint > bankerPoint ? "player" : "banker";
    return {
      player,
      banker,
      playerPoint,
      bankerPoint,
      winner,
      bankerPair: banker[0].rank === banker[1].rank,
      playerPair: player[0].rank === player[1].rank,
    };
  }

  function normalizeMix(inputMix) {
    const raw = Object.assign({}, DEFAULT_MIX, inputMix || {});
    const total = Object.values(raw).reduce((sum, value) => sum + Math.max(0, Number(value) || 0), 0) || 1;
    let cursor = 0;
    return Object.keys(ZONES).map((zone) => {
      cursor += Math.max(0, Number(raw[zone]) || 0) / total;
      return { zone, until: cursor };
    });
  }

  function pickZone(rng, mix) {
    const roll = rng();
    return (mix.find((item) => roll <= item.until) || mix[mix.length - 1]).zone;
  }

  function betAmount(rng, averageBet, volatility) {
    const spread = Math.max(0, Number(volatility) || 0);
    const low = Math.max(0.01, averageBet * (1 - spread));
    const high = Math.max(low, averageBet * (1 + spread));
    return roundMoney(low + rng() * (high - low));
  }

  function settleBet(zone, amount, outcome) {
    let win = false;
    if (zone === "banker") win = outcome.winner === "banker";
    if (zone === "player") win = outcome.winner === "player";
    if (zone === "tie") win = outcome.winner === "tie";
    if (zone === "bankerPair") win = outcome.bankerPair;
    if (zone === "playerPair") win = outcome.playerPair;

    if (win) {
      return {
        win: true,
        payout: amount * (ZONES[zone].odds + 1),
        poolDelta: -amount * ZONES[zone].odds,
      };
    }

    if ((zone === "banker" || zone === "player") && outcome.winner === "tie") {
      return { win: false, push: true, payout: amount, poolDelta: 0 };
    }

    return { win: false, payout: 0, poolDelta: amount };
  }

  function createEmptyZoneStats() {
    return Object.keys(ZONES).reduce((stats, zone) => {
      stats[zone] = { bets: 0, wager: 0, payout: 0, wins: 0 };
      return stats;
    }, {});
  }

  function simulateBaccarat(options, onProgress) {
    const cfg = normalizeOptions(options);
    const rng = createRng(cfg.seed);
    const state = {
      rng,
      decks: cfg.decks,
      cutCard: cfg.cutCard,
      shoe: createShoe(rng, cfg.decks),
      shoes: 1,
    };
    const mix = normalizeMix(cfg.betMix);
    const zoneStats = createEmptyZoneStats();
    const resultStats = {
      banker: 0,
      player: 0,
      tie: 0,
      bankerPair: 0,
      playerPair: 0,
    };
    const poolSeries = [];
    const largeWins = [];
    let pool = cfg.initialPool;
    let minPool = pool;
    let maxPool = pool;
    let bankruptAt = 0;
    let wager = 0;
    let payout = 0;
    let bets = 0;
    let largestPayout = 0;
    const startedAt = now();

    for (let round = 1; round <= cfg.rounds; round += 1) {
      const outcome = dealRound(state);
      resultStats[outcome.winner] += 1;
      if (outcome.bankerPair) resultStats.bankerPair += 1;
      if (outcome.playerPair) resultStats.playerPair += 1;

      for (let player = 0; player < cfg.players; player += 1) {
        if (rng() > cfg.activeRate) continue;
        const zone = pickZone(rng, mix);
        const amount = betAmount(rng, cfg.averageBet, cfg.betVolatility);
        const settlement = settleBet(zone, amount, outcome);
        const stats = zoneStats[zone];

        stats.bets += 1;
        stats.wager += amount;
        stats.payout += settlement.payout;
        if (settlement.win) stats.wins += 1;

        wager += amount;
        payout += settlement.payout;
        bets += 1;
        pool += settlement.poolDelta;
        minPool = Math.min(minPool, pool);
        maxPool = Math.max(maxPool, pool);
        largestPayout = Math.max(largestPayout, settlement.payout);
        if (settlement.payout >= cfg.largeWinThreshold) {
          largeWins.push({ round, zone, amount, payout: settlement.payout, pool: roundMoney(pool) });
          if (largeWins.length > 20) largeWins.shift();
        }
        if (!bankruptAt && pool < 0) bankruptAt = round;
      }

      if (round === 1 || round === cfg.rounds || round % cfg.sampleEvery === 0) {
        poolSeries.push({ round, pool: roundMoney(pool) });
      }
      if (onProgress && round % cfg.progressEvery === 0) onProgress(round, cfg.rounds);
    }

    const elapsedMs = Math.max(1, now() - startedAt);
    return {
      config: cfg,
      rounds: cfg.rounds,
      bets,
      wager: roundMoney(wager),
      payout: roundMoney(payout),
      netProfit: roundMoney(wager - payout),
      rtp: wager > 0 ? payout / wager : 0,
      houseEdge: wager > 0 ? (wager - payout) / wager : 0,
      finalPool: roundMoney(pool),
      minPool: roundMoney(minPool),
      maxPool: roundMoney(maxPool),
      requiredInitialPool: roundMoney(Math.max(0, cfg.initialPool - minPool)),
      bankruptAt,
      largestPayout: roundMoney(largestPayout),
      elapsedMs,
      betsPerSecond: Math.round((bets / elapsedMs) * 1000),
      roundsPerSecond: Math.round((cfg.rounds / elapsedMs) * 1000),
      shoesUsed: state.shoes,
      resultStats,
      zoneStats: formatZoneStats(zoneStats),
      poolSeries,
      largeWins,
    };
  }

  function normalizeOptions(options) {
    const cfg = Object.assign({
      rounds: 100000,
      players: 100,
      activeRate: 0.35,
      averageBet: 100,
      betVolatility: 0.6,
      initialPool: 100000,
      largeWinThreshold: 5000,
      decks: 8,
      cutCard: 52,
      samplePoints: 240,
      progressEvery: 5000,
      seed: "baccarat",
      betMix: DEFAULT_MIX,
    }, options || {});
    cfg.rounds = clampInteger(cfg.rounds, 1, 10000000);
    cfg.players = clampInteger(cfg.players, 1, 100000);
    cfg.activeRate = clampNumber(cfg.activeRate, 0, 1);
    cfg.averageBet = clampNumber(cfg.averageBet, 0.01, 1000000000);
    cfg.betVolatility = clampNumber(cfg.betVolatility, 0, 10);
    cfg.initialPool = clampNumber(cfg.initialPool, 0, 1000000000000);
    cfg.largeWinThreshold = clampNumber(cfg.largeWinThreshold, 0, 1000000000000);
    cfg.decks = clampInteger(cfg.decks, 1, 16);
    cfg.cutCard = clampInteger(cfg.cutCard, 6, cfg.decks * 52 - 6);
    cfg.sampleEvery = Math.max(1, Math.floor(cfg.rounds / clampInteger(cfg.samplePoints, 10, 2000)));
    return cfg;
  }

  function formatZoneStats(zoneStats) {
    return Object.keys(zoneStats).reduce((output, zone) => {
      const stats = zoneStats[zone];
      output[zone] = {
        label: ZONES[zone].label,
        bets: stats.bets,
        wager: roundMoney(stats.wager),
        payout: roundMoney(stats.payout),
        rtp: stats.wager > 0 ? stats.payout / stats.wager : 0,
        winRate: stats.bets > 0 ? stats.wins / stats.bets : 0,
      };
      return output;
    }, {});
  }

  function clampInteger(value, min, max) {
    return Math.min(max, Math.max(min, Math.floor(Number(value) || min)));
  }

  function clampNumber(value, min, max) {
    return Math.min(max, Math.max(min, Number(value) || min));
  }

  function roundMoney(value) {
    return Math.round((Number(value) + Number.EPSILON) * 10000) / 10000;
  }

  function now() {
    if (typeof performance !== "undefined" && performance.now) return performance.now();
    return Date.now();
  }

  return {
    ZONES,
    DEFAULT_MIX,
    createRng,
    dealRound,
    settleBet,
    simulateBaccarat,
  };
});
