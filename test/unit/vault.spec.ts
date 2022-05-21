/* eslint-disable prettier/prettier */
import { expect, assert } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export const vaultTest = (): void => {
  context("#deposit", async function () {
    it("revert if token amount not greater than 0", async function () {
      const amount: BigNumber = ethers.constants.Zero;

      await expect(
        this.vault
          .connect(this.signers.account0)
          .enter(this.mocks.mockUsdc.address, amount)
      ).to.be.revertedWith(`!amount`);
    });
    it("allow if token allowed", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addAllowedTokens(this.mocks.mockUsdc.address);

      await this.vault
        .connect(this.signers.deployer)
        .addStrategy(ethers.constants.AddressZero);

      const amount: BigNumber = ethers.constants.One;

      await expect(
        this.vault
          .connect(this.signers.account0)
          .enter(this.mocks.mockUsdc.address, amount)
      ).to.not.be.revertedWith("!allowedTokens");
    });
    it("revert if token not allowed", async function () {
      const amount: BigNumber = ethers.constants.One;

      await expect(
        this.vault
          .connect(this.signers.account0)
          .enter(this.mocks.mockUsdc.address, amount)
      ).to.be.revertedWith("!allowedTokens");
    });
  });
  context("#strategies", async function () {
    it("addStrategy update variable", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addStrategy(ethers.constants.AddressZero);
      const addressIndexOne = await this.vault.strategies(0);

      assert(addressIndexOne === ethers.constants.AddressZero);
    });
    it("addStrategy onlyOwner", async function () {
      await expect(
        this.vault
          .connect(this.signers.account0)
          .addStrategy(ethers.constants.AddressZero)
      ).to.be.reverted;
    });
    it("retireStrategy update variable", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addStrategy(ethers.constants.AddressZero);

      await this.vault.connect(this.signers.deployer).retireStrategy(0);
      await expect(this.vault.strategies(0)).to.be.reverted;
    });
    it("retireStrategy onlyOwner", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addStrategy(ethers.constants.AddressZero);
      await expect(
        this.vault.connect(this.signers.account0).retireStrategy(0)
      ).to.be.reverted;
    });
  });
  context("#allowedTokens", async function () {
    it("addTokens update variable", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addAllowedTokens(this.mocks.mockUsdc.address);
      const addressIndexOne = await this.vault.allowedTokens(0);
      const addressBool = await this.vault.allowedTokensMapping(
        this.mocks.mockUsdc.address
      );

      assert(addressIndexOne === this.mocks.mockUsdc.address);
      assert(addressBool === true);
    });
    it("addTokens onlyOwner", async function () {
      await expect(
        this.vault
          .connect(this.signers.account0)
          .addAllowedTokens(this.mocks.mockUsdc.address)
      ).to.be.reverted;
    });
    it("retireTokens update variable", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addAllowedTokens(this.mocks.mockUsdc.address);

      await this.vault.connect(this.signers.deployer).retireTokens(0);
      await expect(this.vault.allowedTokens(0)).to.be.reverted;

      const addressBool = await this.vault.allowedTokensMapping(
        this.mocks.mockUsdc.address
      );
      assert(addressBool === false);
    });
    it("retireStrategy onlyOwner", async function () {
      await this.vault
        .connect(this.signers.deployer)
        .addAllowedTokens(this.mocks.mockUsdc.address);
      await expect(
        this.vault.connect(this.signers.account0).retireTokens(0)
      ).to.be.reverted;
    });
  });
  context("#withdraw", async function () {
    it("revert if token amount not greater than 0", async function () {
      const amount: BigNumber = ethers.constants.Zero;

      await expect(
        this.vault.connect(this.signers.account0).withdraw(amount)
      ).to.be.revertedWith(`!amount`);
    });
  });
};
