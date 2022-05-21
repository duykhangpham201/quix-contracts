/* eslint-disable prettier/prettier */
import { waffle } from "hardhat";
import { unitVaultFixture } from "../shared/vaultFixture";
import { Mocks, Signers } from "../shared/types";
import { vaultTest } from "./vault.spec";

describe("Unit tests", async () => {
  before(async function () {
    const wallets = waffle.provider.getWallets();

    this.signers = {} as Signers;
    this.signers.deployer = wallets[0];
    this.signers.account0 = wallets[1];
    this.signers.account1 = wallets[2];

    this.loadFixture = waffle.createFixtureLoader(wallets);
  });

  describe("vault", async () => {
    beforeEach(async function () {
      const { vault, mockUsdc } = await this.loadFixture(unitVaultFixture);
      this.vault = vault;

      this.mocks = {} as Mocks;
      this.mocks.mockUsdc = mockUsdc;
    });

    vaultTest();
  });
});
