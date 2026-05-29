const { expect } = require("chai");
const { ethers } = require("hardhat");

const TokenKind = {
  Native: 0,
  Pepe: 1,
  Usdt: 2,
};

describe("Baccarat", function () {
  async function deployFixture() {
    const [owner, player] = await ethers.getSigners();

    const MockUSDT = await ethers.getContractFactory("MockUSDT");
    const usdt = await MockUSDT.deploy();

    const MockPEPE = await ethers.getContractFactory("MockPEPE");
    const pepe = await MockPEPE.deploy();

    const Baccarat = await ethers.getContractFactory("Baccarat");
    const baccarat = await Baccarat.deploy(pepe.target, usdt.target);

    await usdt.mint(player.address, ethers.parseUnits("1000", 6));
    await pepe.mint(player.address, ethers.parseEther("1000"));

    return { baccarat, pepe, usdt, owner, player };
  }

  it("configures supported token addresses", async function () {
    const { baccarat, pepe, usdt } = await deployFixture();

    expect(await baccarat.contractVersion()).to.equal("baccarat-2026-05-28.1");
    expect(await baccarat.tokenAddress(TokenKind.Native)).to.equal(ethers.ZeroAddress);
    expect(await baccarat.tokenAddress(TokenKind.Pepe)).to.equal(pepe.target);
    expect(await baccarat.tokenAddress(TokenKind.Usdt)).to.equal(usdt.target);
  });

  it("deposits and withdraws native player balance", async function () {
    const { baccarat, player } = await deployFixture();
    const amount = ethers.parseEther("1");

    await expect(
      baccarat.connect(player).depositPlayerBalance(TokenKind.Native, amount, { value: amount }),
    )
      .to.emit(baccarat, "PlayerDeposit")
      .withArgs(player.address, TokenKind.Native, amount, amount);

    expect(await baccarat.playerBalance(player.address, TokenKind.Native)).to.equal(amount);

    await expect(() =>
      baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, amount),
    ).to.changeEtherBalances([player, baccarat], [amount, -amount]);
  });

  it("deposits ERC20 player balance through allowance", async function () {
    const { baccarat, usdt, player } = await deployFixture();
    const amount = ethers.parseUnits("50", 6);

    await usdt.connect(player).approve(baccarat.target, amount);
    await baccarat.connect(player).depositPlayerBalance(TokenKind.Usdt, amount);

    expect(await baccarat.playerBalance(player.address, TokenKind.Usdt)).to.equal(amount);
    expect(await usdt.balanceOf(baccarat.target)).to.equal(amount);
  });

  it("blocks withdrawals while a bet is open", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const amount = ethers.parseEther("1");

    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, amount, { value: amount });
    await baccarat.connect(owner).setPlayerWithdrawalLocked(player.address);

    await expect(
      baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, amount),
    ).to.be.revertedWith("Withdraw locked");
  });

  it("blocks withdrawals while backend withdrawal lock exists", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const amount = ethers.parseEther("1");

    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, amount, { value: amount });

    await expect(baccarat.connect(owner).setPlayerWithdrawalLocked(player.address))
      .to.emit(baccarat, "PlayerWithdrawalLockUpdated")
      .withArgs(player.address, true);

    expect(await baccarat.isWithdrawalLocked(player.address)).to.equal(true);
    expect(await baccarat.playerBalances(player.address)).to.deep.equal([amount, 0n, 0n]);

    await expect(
      baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, amount),
    ).to.be.revertedWith("Withdraw locked");

    await expect(baccarat.connect(owner).setPlayerWithdrawalUnlocked(player.address))
      .to.emit(baccarat, "PlayerWithdrawalLockUpdated")
      .withArgs(player.address, false);
    await expect(() =>
      baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, amount),
    ).to.changeEtherBalances([player, baccarat], [amount, -amount]);
  });

  it("enforces deposit limits and withdrawal maximum", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const minDeposit = ethers.parseEther("1");
    const maxDeposit = ethers.parseEther("5");
    const maxWithdraw = ethers.parseEther("2");

    await expect(
      baccarat.connect(owner).setAmountLimits(TokenKind.Native, minDeposit, maxDeposit, maxWithdraw),
    )
      .to.emit(baccarat, "TokenAmountLimitsUpdated")
      .withArgs(TokenKind.Native, minDeposit, maxDeposit, maxWithdraw);

    await expect(
      baccarat.connect(player).depositPlayerBalance(TokenKind.Native, ethers.parseEther("0.5"), {
        value: ethers.parseEther("0.5"),
      }),
    ).to.be.revertedWith("Amount below minimum");

    await expect(
      baccarat.connect(player).depositPlayerBalance(TokenKind.Native, ethers.parseEther("6"), {
        value: ethers.parseEther("6"),
      }),
    ).to.be.revertedWith("Amount above maximum");

    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, ethers.parseEther("3"), {
      value: ethers.parseEther("3"),
    });

    await baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, ethers.parseEther("0.1"));

    await expect(
      baccarat.connect(player).withdrawPlayerBalance(TokenKind.Native, ethers.parseEther("3")),
    ).to.be.revertedWith("Amount above maximum");
  });

  it("settles wins from the prize pool", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const depositAmount = ethers.parseEther("1");
    const prizeAmount = ethers.parseEther("5");
    const delta = ethers.parseEther("2");

    await baccarat.connect(owner).fundPrizePool(TokenKind.Native, prizeAmount, { value: prizeAmount });
    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, depositAmount, { value: depositAmount });
    await baccarat.connect(player).placeBet(TokenKind.Native);

    await expect(baccarat.connect(owner).settlePlayerBalance(player.address, TokenKind.Native, delta))
      .to.emit(baccarat, "PlayerBalanceSettled")
      .withArgs(player.address, TokenKind.Native, delta, depositAmount + delta);

    expect(await baccarat.playerBalance(player.address, TokenKind.Native)).to.equal(depositAmount + delta);
    expect(await baccarat.prizePoolBalance(TokenKind.Native)).to.equal(prizeAmount - delta);
  });

  it("settles losses into the prize pool", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const depositAmount = ethers.parseEther("3");
    const loss = ethers.parseEther("1");

    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, depositAmount, { value: depositAmount });
    await baccarat.connect(player).placeBet(TokenKind.Native);
    await baccarat.connect(owner).settlePlayerBalance(player.address, TokenKind.Native, -loss);

    expect(await baccarat.playerBalance(player.address, TokenKind.Native)).to.equal(depositAmount - loss);
    expect(await baccarat.prizePoolBalance(TokenKind.Native)).to.equal(loss);
  });

  it("settles multiple player balances in one transaction and skips zero deltas", async function () {
    const { baccarat, owner, player } = await deployFixture();
    const depositAmount = ethers.parseEther("3");
    const prizeAmount = ethers.parseEther("5");
    const win = ethers.parseEther("2");
    const zero = 0n;

    await baccarat.connect(owner).fundPrizePool(TokenKind.Native, prizeAmount, { value: prizeAmount });
    await baccarat.connect(player).depositPlayerBalance(TokenKind.Native, depositAmount, { value: depositAmount });
    await baccarat.connect(player).placeBet(TokenKind.Native);

    await expect(
      baccarat.connect(owner).settlePlayerBalances(
        player.address,
        [TokenKind.Native, TokenKind.Pepe],
        [win, zero],
      ),
    )
      .to.emit(baccarat, "PlayerBalanceSettled")
      .withArgs(player.address, TokenKind.Native, win, depositAmount + win);

    expect(await baccarat.playerBalance(player.address, TokenKind.Native)).to.equal(depositAmount + win);
    expect(await baccarat.playerBalance(player.address, TokenKind.Pepe)).to.equal(0);
    expect(await baccarat.prizePoolBalance(TokenKind.Native)).to.equal(prizeAmount - win);
  });

  it("supports legacy uint8 entrypoints", async function () {
    const { baccarat, player } = await deployFixture();
    const amount = ethers.parseEther("1");

    await baccarat.connect(player).deposit(TokenKind.Native, amount, { value: amount });

    expect(await baccarat.connect(player).getBalance(TokenKind.Native)).to.equal(amount);

    await baccarat.connect(player).bet(TokenKind.Native);
    expect(await baccarat.playerBalance(player.address, TokenKind.Native)).to.equal(amount);
  });

  it("rejects unknown selectors", async function () {
    const { baccarat, owner } = await deployFixture();

    await expect(owner.call({ to: baccarat.target, data: "0x12345678" })).to.be.revertedWith(
      "Use deposit function",
    );
  });

  it("rejects direct native transfers", async function () {
    const { baccarat, player } = await deployFixture();
    const amount = ethers.parseEther("1");

    await expect(
      player.sendTransaction({ to: baccarat.target, value: amount, data: "0x12345678" }),
    ).to.be.revertedWith("Use deposit function");

    await expect(player.sendTransaction({ to: baccarat.target, value: amount })).to.be.revertedWith(
      "Use deposit function",
    );
  });
});
