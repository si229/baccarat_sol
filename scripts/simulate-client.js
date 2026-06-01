const crypto = require("crypto");
const http = require("http");
const { HDNodeWallet, Wallet } = require("ethers");

const HARDHAT_MNEMONIC = process.env.HARDHAT_MNEMONIC || "test test test test test test test test test test test junk";
const PRIVATE_KEYS = (process.env.HARDHAT_PRIVATE_KEYS || "")
  .split(",")
  .map((key) => key.trim())
  .filter((key) => /^0x[a-fA-F0-9]{64}$/.test(key));

const CONFIG = {
  httpBase: process.env.GAME_HTTP_BASE || "http://127.0.0.1:7000",
  wsUrl: process.env.GAME_WS_URL || "ws://127.0.0.1:6006/ws",
  players: numberEnv("SIM_PLAYERS", 1),
  symbol: process.env.SIM_SYMBOL || "USDT",
  seedBalance: numberEnv("SIM_SEED_BALANCE", 1000),
  amount: numberEnv("SIM_BET_AMOUNT", 10),
  zone: numberEnv("SIM_ZONE", 8),
  waitBettingMs: numberEnv("SIM_WAIT_BETTING_MS", 35000),
  waitSettlementMs: numberEnv("SIM_WAIT_SETTLEMENT_MS", 45000),
};

async function main() {
  console.log("simulation config", CONFIG);
  for (let index = 0; index < CONFIG.players; index += 1) {
    const wallet = getWallet(index);
    const client = new GameClient(wallet, index + 1);
    await client.run();
  }
}

function getWallet(index) {
  if (PRIVATE_KEYS.length > 0) {
    return new Wallet(PRIVATE_KEYS[index % PRIVATE_KEYS.length]);
  }
  return HDNodeWallet.fromPhrase(HARDHAT_MNEMONIC, undefined, `m/44'/60'/0'/0/${index}`);
}

class GameClient {
  constructor(wallet, index) {
    this.wallet = wallet;
    this.index = index;
    this.address = wallet.address.toLowerCase();
    this.accessToken = "";
    this.messages = [];
    this.ws = null;
  }

  async run() {
    this.log("start", { address: this.address });
    await this.seedBalance();
    await this.login();
    await this.authorizeBet();
    await this.waitForPhase("betting", CONFIG.waitBettingMs);
    await this.bet();
    await this.waitForPhase("settlement", CONFIG.waitSettlementMs);
    await this.requestBalanceSettle();
    await this.reconnect();
    this.close();
    this.log("done");
  }

  async seedBalance() {
    const body = { address: this.address, symbol: CONFIG.symbol, balance: CONFIG.seedBalance };
    const resp = await postJson(`${CONFIG.httpBase}/api/balance/update`, body);
    this.log("seed balance", resp);
  }

  async login() {
    const nonce = await postJson(`${CONFIG.httpBase}/api/login/nonce`, { address: this.address });
    const once = String(nonce.once);
    const signature = await this.wallet.signMessage(once);

    this.ws = await MiniWebSocket.connect(CONFIG.wsUrl);
    this.bindSocket();
    this.send({ msg_id: "login_req", address: this.address, once, signature });
    const msg = await this.waitForMessage((item) => item.msg_id === "login_resp", 10000);
    if (!msg.access_token) throw new Error(`login failed: ${JSON.stringify(msg)}`);
    this.accessToken = msg.access_token;
    this.log("login ok", summarizeAssets(msg));
  }

  async authorizeBet() {
    this.send({ msg_id: "bet_authorize_req" });
    const msg = await this.waitForMessage((item) => item.msg_id === "bet_authorize_resp", 30000);
    if (msg.code !== 0 || msg.locked !== true) throw new Error(`authorize failed: ${JSON.stringify(msg)}`);
    this.log("authorize ok", msg);
  }

  async bet() {
    this.send({ msg_id: "bet_req", symbol: CONFIG.symbol, zone: CONFIG.zone, amount: CONFIG.amount });
    const msg = await this.waitForMessage((item) => item.msg_id === "bet_push" && item.is_self === true, 10000);
    if (msg.code && msg.code !== 0) throw new Error(`bet failed: ${JSON.stringify(msg)}`);
    this.log("bet ok", msg);
  }

  async requestBalanceSettle() {
    this.send({ msg_id: "balance_settle_req" });
    const msg = await this.waitForMessage((item) => item.msg_id === "balance_settle_resp", 20000).catch((error) => ({
      timeout: true,
      error: error.message,
    }));
    this.log("balance settle result", msg);
  }

  async reconnect() {
    const tokenResp = await postJson(`${CONFIG.httpBase}/api/login/reconnect_token`, {
      address: this.address,
      access_token: this.accessToken,
    });
    if (!tokenResp.token) {
      this.log("reconnect token unavailable", tokenResp);
      return;
    }

    this.close();
    this.messages = [];
    this.ws = await MiniWebSocket.connect(CONFIG.wsUrl);
    this.bindSocket();
    this.send({ msg_id: "reconnect_req", address: this.address, reconnect_token: tokenResp.token });
    const msg = await this.waitForMessage((item) => item.msg_id === "login_resp", 10000);
    if (!msg.access_token) throw new Error(`reconnect failed: ${JSON.stringify(msg)}`);
    this.accessToken = msg.access_token;
    this.log("reconnect ok", summarizeAssets(msg));
  }

  async waitForPhase(phase, timeoutMs) {
    const msg = await this.waitForMessage((item) => item.msg_id === "phase_push" && item.phase === phase, timeoutMs);
    this.log(`phase ${phase}`, { deadline: msg.deadline, round_id: msg.round_id });
    return msg;
  }

  bindSocket() {
    this.ws.onMessage = (text) => {
      try {
        const msg = JSON.parse(text);
        this.messages.push(msg);
        if (msg.msg_id !== "heartbeat_resp") this.log("recv", compactMessage(msg));
      } catch (_error) {
        this.log("recv text", text);
      }
    };
  }

  send(payload) {
    this.log("send", payload);
    this.ws.send(JSON.stringify(payload));
  }

  waitForMessage(predicate, timeoutMs) {
    const existing = this.messages.find(predicate);
    if (existing) return Promise.resolve(existing);
    return new Promise((resolve, reject) => {
      const deadline = Date.now() + timeoutMs;
      const timer = setInterval(() => {
        const msg = this.messages.find(predicate);
        if (msg) {
          clearInterval(timer);
          resolve(msg);
          return;
        }
        if (Date.now() > deadline) {
          clearInterval(timer);
          reject(new Error(`timeout waiting for message after ${timeoutMs}ms`));
        }
      }, 100);
    });
  }

  close() {
    if (this.ws) this.ws.close();
    this.ws = null;
  }

  log(message, data) {
    const prefix = `[client ${this.index} ${this.address.slice(0, 8)}]`;
    if (data === undefined) console.log(prefix, message);
    else console.log(prefix, message, JSON.stringify(data));
  }
}

class MiniWebSocket {
  static connect(url) {
    return new Promise((resolve, reject) => {
      const parsed = new URL(url);
      const key = crypto.randomBytes(16).toString("base64");
      const req = http.request({
        host: parsed.hostname,
        port: parsed.port || 80,
        path: `${parsed.pathname}${parsed.search}`,
        headers: {
          Connection: "Upgrade",
          Upgrade: "websocket",
          "Sec-WebSocket-Version": "13",
          "Sec-WebSocket-Key": key,
        },
      });
      req.on("upgrade", (_res, socket, head) => {
        const ws = new MiniWebSocket(socket);
        if (head.length) ws.consume(head);
        resolve(ws);
      });
      req.on("error", reject);
      req.end();
    });
  }

  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.onMessage = () => {};
    socket.on("data", (chunk) => this.consume(chunk));
  }

  send(text) {
    const payload = Buffer.from(text);
    const mask = crypto.randomBytes(4);
    const header = [];
    header.push(0x81);
    if (payload.length < 126) {
      header.push(0x80 | payload.length);
    } else if (payload.length < 65536) {
      header.push(0x80 | 126, (payload.length >> 8) & 255, payload.length & 255);
    } else {
      throw new Error("payload too large");
    }
    const masked = Buffer.alloc(payload.length);
    for (let i = 0; i < payload.length; i += 1) masked[i] = payload[i] ^ mask[i % 4];
    this.socket.write(Buffer.concat([Buffer.from(header), mask, masked]));
  }

  close() {
    if (!this.socket.destroyed) this.socket.end();
  }

  consume(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 2) {
      const first = this.buffer[0];
      const second = this.buffer[1];
      const opcode = first & 0x0f;
      let offset = 2;
      let length = second & 0x7f;
      if (length === 126) {
        if (this.buffer.length < 4) return;
        length = this.buffer.readUInt16BE(2);
        offset = 4;
      }
      if (this.buffer.length < offset + length) return;
      const payload = this.buffer.slice(offset, offset + length);
      this.buffer = this.buffer.slice(offset + length);
      if (opcode === 1) this.onMessage(payload.toString("utf8"));
      if (opcode === 8) this.close();
    }
  }
}

async function postJson(url, body) {
  const resp = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch (_error) {
    json = { raw: text };
  }
  if (!resp.ok) throw new Error(`${url} failed ${resp.status}: ${text}`);
  return json;
}

function summarizeAssets(msg) {
  return {
    address: msg.address,
    wallet: msg.wallet,
    pending: msg.pending,
    balance: msg.balance,
  };
}

function compactMessage(msg) {
  return {
    msg_id: msg.msg_id,
    phase: msg.phase,
    code: msg.code,
    locked: msg.locked,
    amount: msg.amount,
    symbol: msg.symbol,
    zone: msg.zone,
    is_self: msg.is_self,
    reason: msg.reason,
  };
}

function numberEnv(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
