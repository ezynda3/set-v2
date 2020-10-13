import { Address } from "../types";
import { Signer } from "ethers";
import { BigNumberish, BigNumber } from "ethers/utils";

import {
  AddressArrayUtilsMock,
  ExplicitErc20Mock,
  GodModeMock,
  InvokeMock,
  KyberNetworkProxyMock,
  ManagerIssuanceHookMock,
  ModuleIssuanceHookMock,
  ModuleBaseMock,
  NavIssuanceCaller,
  NavIssuanceHookMock,
  OneInchExchangeMock,
  OracleAdapterMock,
  OracleMock,
  PositionMock,
  PreciseUnitMathMock,
  ResourceIdentifierMock,
  StandardTokenMock,
  StandardTokenWithFeeMock,
  WrapAdapterMock,
} from "../contracts";

import { ether } from "../common";

import { AddressArrayUtilsMockFactory } from "../../typechain/AddressArrayUtilsMockFactory";
import { ExplicitErc20MockFactory } from "../../typechain/ExplicitErc20MockFactory";
import { GodModeMockFactory } from "../../typechain/GodModeMockFactory";
import { InvokeMockFactory } from "../../typechain/InvokeMockFactory";
import { KyberNetworkProxyMockFactory } from "../../typechain/KyberNetworkProxyMockFactory";
import { ManagerIssuanceHookMockFactory } from "../../typechain/ManagerIssuanceHookMockFactory";
import { ModuleBaseMockFactory } from "../../typechain/ModuleBaseMockFactory";
import { ModuleIssuanceHookMockFactory } from "../../typechain/ModuleIssuanceHookMockFactory";
import { NavIssuanceCallerFactory } from "../../typechain/NavIssuanceCallerFactory";
import { NavIssuanceHookMockFactory } from "../../typechain/NavIssuanceHookMockFactory";
import { OneInchExchangeMockFactory } from "../../typechain/OneInchExchangeMockFactory";
import { OracleAdapterMockFactory } from "../../typechain/OracleAdapterMockFactory";
import { OracleMockFactory } from "../../typechain/OracleMockFactory";
import { PositionMockFactory } from "../../typechain/PositionMockFactory";
import { PreciseUnitMathMockFactory } from "../../typechain/PreciseUnitMathMockFactory";
import { ResourceIdentifierMockFactory } from "../../typechain/ResourceIdentifierMockFactory";
import { StandardTokenMockFactory } from "../../typechain/StandardTokenMockFactory";
import { StandardTokenWithFeeMockFactory } from "../../typechain/StandardTokenWithFeeMockFactory";
import { WrapAdapterMockFactory } from "../../typechain/WrapAdapterMockFactory";

export default class DeployMocks {
  private _deployerSigner: Signer;

  constructor(deployerSigner: Signer) {
    this._deployerSigner = deployerSigner;
  }

  public async deployExplicitErc20Mock(): Promise<ExplicitErc20Mock> {
    return await new ExplicitErc20MockFactory(this._deployerSigner).deploy();
  }

  public async deployInvokeMock(): Promise<InvokeMock> {
    return await new InvokeMockFactory(this._deployerSigner).deploy();
  }

  public async deployManagerIssuanceHookMock(): Promise<ManagerIssuanceHookMock> {
    return await new ManagerIssuanceHookMockFactory(this._deployerSigner).deploy();
  }

  public async deployModuleIssuanceHookMock(): Promise<ModuleIssuanceHookMock> {
    return await new ModuleIssuanceHookMockFactory(this._deployerSigner).deploy();
  }

  public async deployNavIssuanceHookMock(): Promise<NavIssuanceHookMock> {
    return await new NavIssuanceHookMockFactory(this._deployerSigner).deploy();
  }

  public async deployNAVIssuanceCaller(navIssuanceModule: Address): Promise<NavIssuanceCaller> {
    return await new NavIssuanceCallerFactory(this._deployerSigner).deploy(navIssuanceModule);
  }

  public async deployAddressArrayUtilsMock(): Promise<AddressArrayUtilsMock> {
    return await new AddressArrayUtilsMockFactory(this._deployerSigner).deploy();
  }

  public async deployKyberNetworkProxyMock(mockWethAddress: Address): Promise<KyberNetworkProxyMock> {
    return await new KyberNetworkProxyMockFactory(this._deployerSigner).deploy(mockWethAddress);
  }

  public async deployModuleBaseMock(controllerAddress: Address): Promise<ModuleBaseMock> {
    return await new ModuleBaseMockFactory(this._deployerSigner).deploy(controllerAddress);
  }

  public async deployGodModeMock(controllerAddress: Address): Promise<GodModeMock> {
    return await new GodModeMockFactory(this._deployerSigner).deploy(controllerAddress);
  }

  public async deployOneInchExchangeMock(
    sendToken: Address,
    receiveToken: Address,
    sendQuantity: BigNumber,
    receiveQuantity: BigNumber,
  ): Promise<OneInchExchangeMock> {
    return await new OneInchExchangeMockFactory(this._deployerSigner).deploy(
      sendToken,
      receiveToken,
      sendQuantity,
      receiveQuantity,
    );
  }

  public async deployOracleMock(initialValue: BigNumberish): Promise<OracleMock> {
    return await new OracleMockFactory(this._deployerSigner).deploy(initialValue);
  }

  public async deployOracleAdapterMock(
    asset: Address,
    dummyPrice: BigNumber
  ): Promise<OracleAdapterMock> {
    return await new OracleAdapterMockFactory(this._deployerSigner).deploy(asset, dummyPrice);
  }

  public async deployPositionMock(): Promise<PositionMock> {
    return await new PositionMockFactory(this._deployerSigner).deploy();
  }

  public async deployPreciseUnitMathMock(): Promise<PreciseUnitMathMock> {
    return await new PreciseUnitMathMockFactory(this._deployerSigner).deploy();
  }

  public async deployResourceIdentifierMock(): Promise<ResourceIdentifierMock> {
    return await new ResourceIdentifierMockFactory(this._deployerSigner).deploy();
  }

  public async deployTokenMock(
    initialAccount: Address,
    initialBalance: BigNumberish = ether(1000000000),
    decimals: BigNumberish = 18,
    name: string = "Token",
    symbol: string = "Symbol"
  ): Promise<StandardTokenMock> {
    return await new StandardTokenMockFactory(this._deployerSigner)
      .deploy(initialAccount, initialBalance, name, symbol, decimals);
  }

  public async deployTokenWithFeeMock(
    initialAccount: Address,
    initialBalance: BigNumberish = ether(1000000000),
    fee: BigNumberish = ether(0.1),
    name: string = "Token",
    symbol: string = "Symbol"
  ): Promise<StandardTokenWithFeeMock> {
    return await new StandardTokenWithFeeMockFactory(this._deployerSigner)
      .deploy(initialAccount, initialBalance, name, symbol, fee);
  }

  public async deployWrapAdapterMock(): Promise<WrapAdapterMock> {
    return await new WrapAdapterMockFactory(this._deployerSigner).deploy();
  }

  /*************************************
   * Instance getters
   ************************************/

  public async getTokenMock(token: Address): Promise<StandardTokenMock> {
    return await new StandardTokenMockFactory(this._deployerSigner).attach(token);
  }
}
