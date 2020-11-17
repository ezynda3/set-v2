import { Signer } from "ethers";

import {
  AaveGovernanceAdapter,
  CompoundLikeGovernanceAdapter,
  KyberExchangeAdapter,
  OneInchExchangeAdapter,
  AaveMigrationWrapAdapter,
  UniswapPairPriceAdapter
} from "../contracts";

import { Address, Bytes } from "./../types";

import { AaveGovernanceAdapterFactory } from "../../typechain/AaveGovernanceAdapterFactory";
import { CompoundLikeGovernanceAdapterFactory } from "../../typechain/CompoundLikeGovernanceAdapterFactory";
import { KyberExchangeAdapterFactory } from "../../typechain/KyberExchangeAdapterFactory";
import { OneInchExchangeAdapterFactory } from "../../typechain/OneInchExchangeAdapterFactory";
import { AaveMigrationWrapAdapterFactory } from "../../typechain/AaveMigrationWrapAdapterFactory";
import { UniswapPairPriceAdapterFactory } from "../../typechain/UniswapPairPriceAdapterFactory";

export default class DeployAdapters {
  private _deployerSigner: Signer;

  constructor(deployerSigner: Signer) {
    this._deployerSigner = deployerSigner;
  }

  public async deployKyberExchangeAdapter(kyberNetworkProxy: Address): Promise<KyberExchangeAdapter> {
    return await new KyberExchangeAdapterFactory(this._deployerSigner).deploy(kyberNetworkProxy);
  }

  public async deployOneInchExchangeAdapter(
    approveAddress: Address,
    exchangeAddress: Address,
    swapFunctionSignature: Bytes
  ): Promise<OneInchExchangeAdapter> {
    return await new OneInchExchangeAdapterFactory(this._deployerSigner).deploy(
      approveAddress,
      exchangeAddress,
      swapFunctionSignature
    );
  }

  public async deployAaveGovernanceAdapter(aaveProtoGovernance: Address, aaveToken: Address): Promise<AaveGovernanceAdapter> {
    return await new AaveGovernanceAdapterFactory(this._deployerSigner).deploy(aaveProtoGovernance, aaveToken);
  }

  public async deployAaveMigrationWrapAdapter(
    aaveMigrationProxy: Address,
    lendToken: Address,
    aaveToken: Address
  ): Promise<AaveMigrationWrapAdapter> {
    return await new AaveMigrationWrapAdapterFactory(this._deployerSigner).deploy(aaveMigrationProxy, lendToken, aaveToken);
  }

  public async deployCompoundLikeGovernanceAdapter(governanceAlpha: Address, governanceToken: Address): Promise<CompoundLikeGovernanceAdapter> {
    return await new CompoundLikeGovernanceAdapterFactory(this._deployerSigner).deploy(governanceAlpha, governanceToken);
  }

  public async deployUniswapPairPriceAdapter(
    controller: Address,
    uniswapFactory: Address,
    uniswapPools: Address[]
  ): Promise<UniswapPairPriceAdapter> {
    return await new UniswapPairPriceAdapterFactory(this._deployerSigner).deploy(controller, uniswapFactory, uniswapPools);
  }
}
