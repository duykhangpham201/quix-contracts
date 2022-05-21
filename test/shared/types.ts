/* eslint-disable prettier/prettier */
import { Fixture, MockContract } from "ethereum-waffle";
import { Wallet } from "@ethersproject/wallet";
import { QuixVault, StrategyQuickSwap, StrategySushiLP } from "../../typechain";

export interface Signers {
  deployer: Wallet;
  account0: Wallet;
  account1: Wallet;
}

export interface Mocks {
  mockUsdc: MockContract;
}

declare module "mocha" {
  export interface Context {
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
    mocks: Mocks;
    vault: QuixVault;
    stratQuick: StrategyQuickSwap;
    stratSushi: StrategySushiLP;
  }
}
