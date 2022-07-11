import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { n18 } from "./helpers";

describe("Vault Pool", () => {
  async function deployTokenAndVault() {
    const THREE_MONTHS_IN_SECONDS = 90 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;
    const unlockDuration = THREE_MONTHS_IN_SECONDS;

    const unlockTime = (await time.latest()) + THREE_MONTHS_IN_SECONDS;

    const [owner, staker1, staker2] = await ethers.getSigners();

    const Vault = await ethers.getContractFactory("Vault");
    const Token = await ethers.getContractFactory("Token");

    const token = await Token.deploy(n18("10000"));
    await token.transfer(staker1.address, n18("1000"));
    await token.transfer(staker2.address, n18("1000"));

    const vault = await Vault.deploy(token.address, 89, 90, 90);

    return {
      vault,
      token,
      unlockDuration,
      owner,
      staker1,
      staker2,
      unlockTime,
    };
  }

  describe("Deployment", () => {
    it("Should deploy the new Token and Vault", async () => {
      const { vault, token, staker1, staker2 } = await loadFixture(
        deployTokenAndVault
      );

      expect(vault.address).to.not.be.undefined;
      expect(token.address).to.not.be.undefined;
      expect(await vault.token()).to.equal(token.address);
      expect(await token.balanceOf(staker1.address)).to.be.equal(n18("1000"));
      expect(await token.balanceOf(staker2.address)).to.be.equal(n18("1000"));
    });

    it("Should have unlock time equal to 3 months", async () => {
      const { vault, unlockDuration } = await loadFixture(deployTokenAndVault);

      expect(await vault.lockupDuration()).to.equal(unlockDuration);
    });

    it("Should have right owner", async () => {
      const { vault, owner } = await loadFixture(deployTokenAndVault);
      expect(await vault.owner()).to.equal(owner.address);
    });
  });

  describe("Deposit", () => {
    it("Amount must be greater than 0", async () => {
      const { vault, token, owner } = await loadFixture(deployTokenAndVault);

      expect(await token.balanceOf(vault.address)).to.equal(0);

      await token.approve(vault.address, n18("100"));
      await expect(vault.deposit(n18("0"))).to.be.revertedWith(
        "Amount must be greater than 0"
      );
    });

    it("Can deposit", async () => {
      const { vault, token, owner } = await loadFixture(deployTokenAndVault);

      expect(await token.balanceOf(vault.address)).to.equal(0);

      await token.approve(vault.address, n18("100"));
      await vault.deposit(n18("100"));
      expect(await vault.amountStaked(owner.address)).to.equal(n18("100"));
      expect(await vault.totalDeposited()).to.equal(n18("100"));
    });

    it("2 stakers can deposit", async () => {
      const { vault, token, owner, staker1 } = await loadFixture(
        deployTokenAndVault
      );

      expect(await token.balanceOf(vault.address)).to.equal(0);

      await token.approve(vault.address, n18("100"));
      await vault.deposit(n18("100"));

      await token.connect(staker1).approve(vault.address, n18("100"));
      await vault.connect(staker1).deposit(n18("100"));

      expect(await vault.amountStaked(owner.address)).to.equal(n18("100"));
      expect(await vault.amountStaked(staker1.address)).to.equal(n18("100"));

      expect(await vault.totalDeposited()).to.equal(n18("200"));
    });
  });

  describe("Staking", () => {
    it("Owner can start staking", async () => {
      const { vault, token, owner, staker1 } = await loadFixture(
        deployTokenAndVault
      );

      await expect(vault.connect(staker1).startStaking()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );

      await expect(vault.startStaking()).to.emit(vault, "StartStaking");
    });

    it("Three months staking will pay off", async () => {
      const { vault, token, owner, staker1, unlockTime } = await loadFixture(
        deployTokenAndVault
      );
      await token.approve(vault.address, n18("100"));
      await expect(vault.deposit(n18("100"))).to.emit(vault, "Deposit");

      await expect(vault.startStaking()).to.emit(vault, "StartStaking");
      expect(await vault.rewardOf(owner.address)).to.be.equal(n18("0"));

      await time.increaseTo(unlockTime);

      const reward = await vault.rewardOf(owner.address);

      console.log("reward here", reward);
      // TODO fix precision
      expect(reward).to.be.closeTo(n18("8.9").div(365).mul(90), n18("0.1"));
    });
  });

  //   describe("Withdrawals", () => {
  //     it("Should revert with right error if called to soon", async () => {
  //       const { vault } = await loadFixture(deployTokenAndVault);
  //     });
  //   });
});
