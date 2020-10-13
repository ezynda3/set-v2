import { Signer } from "ethers";
import { BigNumber } from "ethers/utils";

import {
  Weth9
} from "./../contracts";

import { Address } from "./../types";

import { Weth9Factory } from "../../typechain/Weth9Factory";

import {
  LendToAaveMigrator
} from "../contracts/aave";

import { LendToAaveMigratorFactory } from "../../typechain/LendToAaveMigratorFactory";

import {
  StakingRewards,
  Uni,
  UniswapV2Factory,
  UniswapV2Pair,
  UniswapV2Router02
} from "../contracts/uniswap";

import { StakingRewardsFactory } from "../../typechain/StakingRewardsFactory";
import { UniFactory } from "../../typechain/UniFactory";
import { UniswapV2FactoryFactory } from "../../typechain/UniswapV2FactoryFactory";
import { UniswapV2PairFactory } from "../../typechain/UniswapV2PairFactory";
import { UniswapV2Router02Factory } from "../../typechain/UniswapV2Router02Factory";

export default class DeployExternalContracts {
  private _deployerSigner: Signer;

  constructor(deployerSigner: Signer) {
    this._deployerSigner = deployerSigner;
  }

  // WETH
  public async deployWETH(): Promise<Weth9> {
    return await new Weth9Factory(this._deployerSigner).deploy();
  }

  // AAVE
  public async deployLendToAaveMigrator(
    _aaveToken: Address,
    _lendToken: Address,
    _aaveLendRatio: BigNumber,
  ): Promise<LendToAaveMigrator> {
    return await new LendToAaveMigratorFactory(this._deployerSigner).deploy(
      _aaveToken,
      _lendToken,
      _aaveLendRatio
    );
  }

  // Uniswap
  public async deployUni(_account: Address, _minter: Address, _mintingAllowedAfter: BigNumber): Promise<Uni> {
    return await new UniFactory(this._deployerSigner).deploy(_account, _minter, _mintingAllowedAfter);
  }

  public async deployUniswapV2Factory(_feeToSetter: string): Promise<UniswapV2Factory> {
    return await new UniswapV2FactoryFactory(this._deployerSigner).deploy(_feeToSetter);
  }

  public async deployUniswapV2Router02(_factory: Address, _weth: Address): Promise<UniswapV2Router02> {
    return await new UniswapV2Router02Factory(this._deployerSigner).deploy(_factory, _weth);
  }

  public async deployUniswapV2Pair(_factory: Address, _weth: Address): Promise<UniswapV2Pair> {
    return await new UniswapV2PairFactory(this._deployerSigner).deploy();
  }

  public async deployStakingRewards(
    _rewardsDistribution: Address,
    _rewardsToken: Address,
    _stakingToken: Address
  ): Promise<StakingRewards> {
    return await new StakingRewardsFactory(this._deployerSigner).deploy(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken
    );
  }
}
