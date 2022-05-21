/* eslint-disable prettier/prettier */
import { Fixture, MockContract } from "ethereum-waffle";
import { ContractFactory, Wallet } from "ethers";
import { ethers } from "hardhat";
import { QuixVault } from "../../typechain";
import { deployMockUsdc } from "./mocks";

type UnitVaultFixtureType = {
  vault: QuixVault;
  mockUsdc: MockContract;
};

export const unitVaultFixture: Fixture<UnitVaultFixtureType> = async (
  signers: Wallet[]
) => {
  const deployer: Wallet = signers[0];

  const vaultFactory: ContractFactory = await ethers.getContractFactory(
    "QuixVault"
  );

  const vaultParams = {
    name: "QuixVault",
    symbol: "qUSD",
    rewardRate: 1,
  };
  const vault: QuixVault = (await vaultFactory
    .connect(deployer)
    .deploy(...Object.values(vaultParams))) as QuixVault;

  await vault.deployed();

  const mockUsdc = await deployMockUsdc(deployer);

  return { vault, mockUsdc };
};
