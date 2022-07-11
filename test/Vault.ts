import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { n18 } from "./helpers";

describe("Vault Pool", () => {
  async function deployTokenAndVault() {
    const THREE_MONTHS_IN_SECONDS = 90 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;
    const unlockDuration = THREE_MONTHS_IN_SECONDS;

    const [owner, staker1, staker2] = await ethers.getSigners();

    const Vault = await ethers.getContractFactory("Vault");
    const Token = await ethers.getContractFactory("Token");

    const token = await Token.deploy(n18("10000"));
    await token.transfer(staker1.address, n18("1000"));
    await token.transfer(staker2.address, n18("1000"));

    const vault = await Vault.deploy(token.address, 9, 90, 90);

    return { vault, token, unlockDuration, owner, staker1, staker2 };
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
  });

  //   describe("Withdrawals", () => {
  //     it("Should revert with right error if called to soon", async () => {
  //       const { vault } = await loadFixture(deployTokenAndVault);
  //     });
  //   });
});
