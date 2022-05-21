/* eslint-disable prettier/prettier */
import { Fixture, MockContract } from "ethereum-waffle";
import { ContractFactory, Wallet } from "ethers";
import { ethers } from "hardhat";
import { StrategySushiLP, StrategyQuickSwap } from "../../typechain";
import { deployMockUsdc, deployMockUsdt, deployMockOutput } from "./mocks";

type unitStratSushiFixtureType = {
  stratSushi: StrategySushiLP;
  mockUsdc: MockContract;
  mockUsdt: MockContract;
  mockOutput: MockContract;
};

type unitStratQuickFixtureType = {
  stratQuick: StrategyQuickSwap;
  mockUsdc: MockContract;
  mockUsdt: MockContract;
  mockOutput: MockContract;
};

export const unitStratSushiFixture: Fixture<unitStratSushiFixtureType> = async (
  signers: Wallet[]
) => {
  const deployer: Wallet = signers[0];

  const mockUsdc = await deployMockUsdc(deployer);
  const mockUsdt = await deployMockUsdt(deployer);
  const mockOutput = await deployMockOutput(deployer);

  const stratSushiFactory: ContractFactory = await ethers.getContractFactory(
    "StrategySushiLp"
  );

  const stratSushiParams = {
    want: ethers.constants.AddressZero,
    poolId: 0,
    chef: 0,
    vault: ethers.constants.AddressZero,
    unirouter: ethers.constants.AddressZero,
    feeRecipient: deployer.address,
    fee: 10,
    outputToNativeRoute: [mockOutput.address, ethers.constants.AddressZero],
    outputToLp0Route: [mockOutput.address, mockUsdc.address],
    outputToLp1Route: [mockOutput.address, mockUsdt.address],
    lpToken1ToLpToken0Route: [mockUsdc.address, mockUsdt.address],
  };

  const stratSushi: StrategySushiLP = (await stratSushiFactory
    .connect(deployer)
    .deploy(...Object.values(stratSushiParams))) as StrategySushiLP;

  await stratSushi.deployed();

  return { stratSushi, mockUsdc, mockUsdt, mockOutput };
};

export const unitStratQuickFixture: Fixture<unitStratQuickFixtureType> = async (
  signers: Wallet[]
) => {
  const deployer: Wallet = signers[0];

  const mockUsdc = await deployMockUsdc(deployer);
  const mockUsdt = await deployMockUsdt(deployer);
  const mockOutput = await deployMockOutput(deployer);

  const stratQuickFactory: ContractFactory = await ethers.getContractFactory(
    "StrategyQuickSwap"
  );

  const stratQuickParams = {
    want: ethers.constants.AddressZero,
    rewardPool: ethers.constants.AddressZero,
    vault: ethers.constants.AddressZero,
    unirouter: ethers.constants.AddressZero,
    feeRecipient: deployer.address,
    fee: 10,
    outputToNativeRoute: [mockOutput.address, ethers.constants.AddressZero],
    outputToLp0Route: [mockOutput.address, mockUsdc.address],
    outputToLp1Route: [mockOutput.address, mockUsdt.address],
    lpToken1ToLpToken0Route: [mockUsdc.address, mockUsdt.address],
  };

  const stratQuick: StrategyQuickSwap = (await stratQuickFactory
    .connect(deployer)
    .deploy(...Object.values(stratQuickParams))) as StrategyQuickSwap;

  await stratQuick.deployed();

  return { stratQuick, mockUsdc, mockUsdt, mockOutput };
};
