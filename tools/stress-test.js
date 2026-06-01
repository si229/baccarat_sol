const form = document.querySelector("#simForm");
const runBtn = document.querySelector("#runBtn");
const exportBtn = document.querySelector("#exportBtn");
const progressBar = document.querySelector("#progressBar");
const poolChart = document.querySelector("#poolChart");
const ctx = poolChart.getContext("2d");

let lastResult = null;

const presets = {
  balanced: {
    rounds: 100000,
    players: 160,
    activeRate: 0.38,
    averageBet: 100,
    betVolatility: 0.65,
    initialPool: 120000,
    largeWinThreshold: 5000,
    mix: { banker: 45, player: 40, tie: 5, bankerPair: 5, playerPair: 5 },
  },
  highroller: {
    rounds: 80000,
    players: 60,
    activeRate: 0.52,
    averageBet: 1000,
    betVolatility: 1.1,
    initialPool: 800000,
    largeWinThreshold: 25000,
    mix: { banker: 47, player: 43, tie: 4, bankerPair: 3, playerPair: 3 },
  },
  pairs: {
    rounds: 120000,
    players: 120,
    activeRate: 0.42,
    averageBet: 160,
    betVolatility: 0.9,
    initialPool: 260000,
    largeWinThreshold: 8000,
    mix: { banker: 30, player: 30, tie: 8, bankerPair: 16, playerPair: 16 },
  },
};

document.querySelectorAll("[data-preset]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-preset]").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    applyPreset(presets[button.dataset.preset]);
  });
});

runBtn.addEventListener("click", () => runSimulation());
exportBtn.addEventListener("click", () => exportResult());
drawEmptyChart();

function applyPreset(preset) {
  Object.entries(preset).forEach(([key, value]) => {
    if (key === "mix") return;
    const input = form.elements[key];
    if (input) input.value = value;
  });
  Object.entries(preset.mix).forEach(([key, value]) => {
    const input = document.querySelector(`[name="mix-${key}"]`);
    if (input) input.value = value;
  });
}

function readOptions() {
  return {
    rounds: form.elements.rounds.value,
    players: form.elements.players.value,
    activeRate: form.elements.activeRate.value,
    averageBet: form.elements.averageBet.value,
    betVolatility: form.elements.betVolatility.value,
    initialPool: form.elements.initialPool.value,
    largeWinThreshold: form.elements.largeWinThreshold.value,
    seed: form.elements.seed.value,
    betMix: {
      banker: valueOf("mix-banker"),
      player: valueOf("mix-player"),
      tie: valueOf("mix-tie"),
      bankerPair: valueOf("mix-bankerPair"),
      playerPair: valueOf("mix-playerPair"),
    },
  };
}

function valueOf(name) {
  const input = document.querySelector(`[name="${name}"]`);
  return input ? input.value : 0;
}

function runSimulation() {
  runBtn.disabled = true;
  exportBtn.disabled = true;
  runBtn.textContent = "测试中...";
  progressBar.style.width = "0%";

  setTimeout(() => {
    try {
      const result = BaccaratSim.simulateBaccarat(readOptions(), (round, total) => {
        progressBar.style.width = `${Math.round((round / total) * 100)}%`;
      });
      progressBar.style.width = "100%";
      lastResult = result;
      renderResult(result);
      exportBtn.disabled = false;
    } finally {
      runBtn.disabled = false;
      runBtn.textContent = "开始测试";
    }
  }, 40);
}

function renderResult(result) {
  setText("rtpValue", percent(result.rtp));
  setText("profitValue", money(result.netProfit));
  setText("poolNeedValue", money(result.requiredInitialPool));
  setText("throughputValue", `${formatInt(result.betsPerSecond)}/秒`);
  setText("poolRange", `最低 ${money(result.minPool)} / 最高 ${money(result.maxPool)} / 结束 ${money(result.finalPool)}`);
  setText("runMeta", `${formatInt(result.rounds)} 局，${formatInt(result.bets)} 注，耗时 ${result.elapsedMs.toFixed(0)} ms`);

  renderZoneRows(result.zoneStats);
  renderResultStats(result.resultStats, result.rounds);
  renderRisk(result);
  drawPoolChart(result.poolSeries);
}

function renderZoneRows(zoneStats) {
  const rows = Object.values(zoneStats).map((item) => `
    <tr>
      <td>${item.label}</td>
      <td>${formatInt(item.bets)}</td>
      <td>${money(item.wager)}</td>
      <td>${money(item.payout)}</td>
      <td>${percent(item.rtp)}</td>
      <td>${percent(item.winRate)}</td>
    </tr>
  `);
  document.querySelector("#zoneRows").innerHTML = rows.join("");
}

function renderResultStats(stats, rounds) {
  const labels = {
    banker: "庄赢",
    player: "闲赢",
    tie: "和局",
    bankerPair: "庄对",
    playerPair: "闲对",
  };
  document.querySelector("#resultStats").innerHTML = Object.entries(labels).map(([key, label]) => {
    const rate = stats[key] / rounds;
    return `
      <div class="stat-item">
        <strong>${label}</strong>
        <div class="bar"><span style="width:${Math.min(100, rate * 100)}%"></span></div>
        <span>${percent(rate)}</span>
      </div>
    `;
  }).join("");
}

function renderRisk(result) {
  const margin = result.config.initialPool - result.requiredInitialPool;
  const poolClass = result.bankruptAt ? "danger" : margin < result.config.initialPool * 0.15 ? "warn" : "good";
  const status = result.bankruptAt
    ? `第 ${formatInt(result.bankruptAt)} 局奖池跌破 0，当前初始奖池不足。`
    : `当前初始奖池未爆池，安全垫约 ${money(margin)}。`;

  document.querySelector("#riskText").innerHTML = `
    <strong class="${poolClass}">${status}</strong>
    平台收益率 ${percent(result.houseEdge)}，最大单注派奖 ${money(result.largestPayout)}。
    建议按最低奖池回撤再加 20% 到 50% 运营缓冲准备初始奖池。
  `;

  document.querySelector("#largeWins").innerHTML = result.largeWins.length
    ? result.largeWins.slice(-8).reverse().map((item) =>
        `<div>第 ${formatInt(item.round)} 局 ${item.zone} 下注 ${money(item.amount)}，派奖 ${money(item.payout)}，派奖后奖池 ${money(item.pool)}</div>`,
      ).join("")
    : "<div>没有达到记录线的大额派奖。</div>";
}

function drawEmptyChart() {
  ctx.clearRect(0, 0, poolChart.width, poolChart.height);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, poolChart.width, poolChart.height);
  ctx.fillStyle = "#667085";
  ctx.font = "24px Arial";
  ctx.fillText("等待测试数据", 48, 72);
}

function drawPoolChart(series) {
  const width = poolChart.width;
  const height = poolChart.height;
  const pad = 46;
  const values = series.map((item) => item.pool);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = Math.max(1, max - min);

  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, width, height);
  ctx.strokeStyle = "#d9e1ec";
  ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i += 1) {
    const y = pad + ((height - pad * 2) * i) / 4;
    ctx.beginPath();
    ctx.moveTo(pad, y);
    ctx.lineTo(width - pad, y);
    ctx.stroke();
  }

  ctx.strokeStyle = "#2563eb";
  ctx.lineWidth = 3;
  ctx.beginPath();
  series.forEach((item, index) => {
    const x = pad + ((width - pad * 2) * index) / Math.max(1, series.length - 1);
    const y = height - pad - ((item.pool - min) / span) * (height - pad * 2);
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.stroke();

  ctx.fillStyle = "#152033";
  ctx.font = "18px Arial";
  ctx.fillText(`max ${money(max)}`, pad, 28);
  ctx.fillText(`min ${money(min)}`, pad, height - 16);
}

function exportResult() {
  if (!lastResult) return;
  const blob = new Blob([JSON.stringify(lastResult, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `baccarat-stress-${Date.now()}.json`;
  link.click();
  URL.revokeObjectURL(url);
}

function setText(id, value) {
  document.querySelector(`#${id}`).textContent = value;
}

function money(value) {
  return Number(value).toLocaleString("zh-CN", { maximumFractionDigits: 2 });
}

function formatInt(value) {
  return Number(value).toLocaleString("zh-CN", { maximumFractionDigits: 0 });
}

function percent(value) {
  return `${(Number(value) * 100).toFixed(2)}%`;
}
