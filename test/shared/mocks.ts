/* eslint-disable prettier/prettier */
import { MockContract } from "ethereum-waffle";
import { Signer } from "ethers";
import { waffle } from "hardhat";
import ERC_20_ABI from "../../abis/erc20.abi.json";

export async function deployMockUsdc(deployer: Signer): Promise<MockContract> {
  const erc20: MockContract = await waffle.deployMockContract(
    deployer,
    ERC_20_ABI
  );

  await erc20.mock.decimals.returns(18);
  await erc20.mock.name.returns(`USD Coin`);
  await erc20.mock.symbol.returns(`USDC`);
  await erc20.mock.transferFrom.returns(true);

  return erc20;
}

export async function deployMockUsdt(deployer: Signer): Promise<MockContract> {
  const erc20: MockContract = await waffle.deployMockContract(
    deployer,
    ERC_20_ABI
  );

  await erc20.mock.decimals.returns(18);
  await erc20.mock.name.returns(`USD Tether`);
  await erc20.mock.symbol.returns(`USDT`);
  await erc20.mock.transferFrom.returns(true);

  return erc20;
}

export async function deployMockOutput(
  deployer: Signer
): Promise<MockContract> {
  const erc20: MockContract = await waffle.deployMockContract(
    deployer,
    ERC_20_ABI
  );

  await erc20.mock.decimals.returns(18);
  await erc20.mock.name.returns(`Output`);
  await erc20.mock.symbol.returns(`OPT`);
  await erc20.mock.transferFrom.returns(true);

  return erc20;
}
