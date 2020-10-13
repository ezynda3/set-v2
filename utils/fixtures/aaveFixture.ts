import DeployHelper from "../deploys";
import { Signer } from "ethers";
import { JsonRpcProvider, Web3Provider } from "ethers/providers";
import { Address } from "../types";
import { BigNumber } from "ethers/utils";

import {
  LendToAaveMigrator,
} from "../contracts/aave";

import { StandardTokenMock } from "../contracts";

import { ether } from "../common";

export class AaveFixture {
  private _deployer: DeployHelper;
  private _ownerSigner: Signer;

  public lendToAaveMigrator: LendToAaveMigrator;
  public lendToken: StandardTokenMock;
  public aaveToken: StandardTokenMock;
  public aaveExchangeRatio: BigNumber;

  constructor(provider: Web3Provider | JsonRpcProvider, ownerAddress: Address) {
    this._ownerSigner = provider.getSigner(ownerAddress);
    this._deployer = new DeployHelper(this._ownerSigner);
  }

  public async initialize(): Promise<void> {
    this.lendToken = await this._deployer.mocks.deployTokenMock(await this._ownerSigner.getAddress(), ether(1000000), 18);
    this.aaveToken = await this._deployer.mocks.deployTokenMock(await this._ownerSigner.getAddress(), ether(10000), 18);
    this.aaveExchangeRatio = new BigNumber(100); // 100:1 LEND to AAVE ratio
    this.lendToAaveMigrator = await this._deployer.external.deployLendToAaveMigrator(
      this.aaveToken.address,
      this.lendToken.address,
      this.aaveExchangeRatio
    );

    // Transfer tokens to contract for migration
    await this.lendToken.transfer(this.lendToAaveMigrator.address, ether(10000));
    await this.aaveToken.transfer(this.lendToAaveMigrator.address, ether(100));

    await this.lendToAaveMigrator.initialize();
  }
}
