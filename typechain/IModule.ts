/* Generated by ts-generator ver. 0.0.8 */
/* tslint:disable */

import { Contract, ContractTransaction, EventFilter, Signer } from "ethers";
import { Listener, Provider } from "ethers/providers";
import { Arrayish, BigNumber, BigNumberish, Interface } from "ethers/utils";
import {
  TransactionOverrides,
  TypedEventDescription,
  TypedFunctionDescription
} from ".";

interface IModuleInterface extends Interface {
  functions: {
    removeModule: TypedFunctionDescription<{ encode([]: []): string }>;
  };

  events: {};
}

export declare class IModule extends Contract {
  connect(signerOrProvider: Signer | Provider | string): IModule;
  attach(addressOrName: string): IModule;
  deployed(): Promise<IModule>;

  on(event: EventFilter | string, listener: Listener): IModule;
  once(event: EventFilter | string, listener: Listener): IModule;
  addListener(eventName: EventFilter | string, listener: Listener): IModule;
  removeAllListeners(eventName: EventFilter | string): IModule;
  removeListener(eventName: any, listener: Listener): IModule;

  interface: IModuleInterface;

  functions: {
    removeModule(
      overrides?: TransactionOverrides
    ): Promise<ContractTransaction>;
  };

  removeModule(overrides?: TransactionOverrides): Promise<ContractTransaction>;

  filters: {};

  estimate: {
    removeModule(): Promise<BigNumber>;
  };
}