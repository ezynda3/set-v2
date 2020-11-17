import { Signer } from "ethers";

import {
  BasicIssuanceModule,
  GovernanceModule,
  NavIssuanceModule,
  SingleIndexModule,
  StreamingFeeModule,
  TradeModule,
  UniswapYieldStrategy,
  WrapModule
} from "../contracts";
import { Address } from "../types";

import { BasicIssuanceModuleFactory } from "../../typechain/BasicIssuanceModuleFactory";
import { GovernanceModuleFactory } from "../../typechain/GovernanceModuleFactory";
import { NavIssuanceModuleFactory } from "../../typechain/NavIssuanceModuleFactory";
import { SingleIndexModuleFactory } from "../../typechain/SingleIndexModuleFactory";
import { StreamingFeeModuleFactory } from "../../typechain/StreamingFeeModuleFactory";
import { TradeModuleFactory } from "../../typechain/TradeModuleFactory";
import { UniswapYieldStrategyFactory } from "../../typechain/UniswapYieldStrategyFactory";
import { WrapModuleFactory } from "../../typechain/WrapModuleFactory";

export default class DeployModules {
  private _deployerSigner: Signer;

  constructor(deployerSigner: Signer) {
    this._deployerSigner = deployerSigner;
  }

  public async deployBasicIssuanceModule(controller: Address): Promise<BasicIssuanceModule> {
    return await new BasicIssuanceModuleFactory(this._deployerSigner).deploy(controller);
  }

  public async deployStreamingFeeModule(controller: Address): Promise<StreamingFeeModule> {
    return await new StreamingFeeModuleFactory(this._deployerSigner).deploy(controller);
  }

  public async deployNavIssuanceModule(controller: Address, weth: Address): Promise<NavIssuanceModule> {
    return await new NavIssuanceModuleFactory(this._deployerSigner).deploy(controller, weth);
  }

  public async deployTradeModule(controller: Address): Promise<TradeModule> {
    return await new TradeModuleFactory(this._deployerSigner).deploy(controller);
  }

  public async deployWrapModule(controller: Address, weth: Address): Promise<WrapModule> {
    return await new WrapModuleFactory(this._deployerSigner).deploy(controller, weth);
  }

  public async deployUniswapYieldStrategy(
    _controller: Address,
    _uniswapRouter: Address,
    _lpToken: Address,
    _assetOne: Address,
    _assetTwo: Address,
    _uni: Address,
    _rewarder: Address,
    _feeRecipient: Address
  ): Promise<UniswapYieldStrategy> {
    return await new UniswapYieldStrategyFactory(this._deployerSigner).deploy(
      _controller,
      _uniswapRouter,
      _lpToken,
      _assetOne,
      _assetTwo,
      _uni,
      _rewarder,
      _feeRecipient
    );
  }

  public async deploySingleIndexModule(
    controller: Address,
    weth: Address,
    uniswapRouter: Address,
    sushiswapRouter: Address,
    balancerProxy: Address
  ): Promise<SingleIndexModule> {
    return await new SingleIndexModuleFactory(this._deployerSigner).deploy(
      controller,
      weth,
      uniswapRouter,
      sushiswapRouter,
      balancerProxy,
    );
  }

  public async deployGovernanceModule(controller: Address): Promise<GovernanceModule> {
    return await new GovernanceModuleFactory(this._deployerSigner).deploy(controller);
  }
}
