import { Contract, ContractTransaction, EventFilter, Signer } from "ethers";
import { Listener, Provider } from "ethers/providers";
import { BigNumber, BigNumberish, Interface } from "ethers/utils";
import { TransactionOverrides, TypedFunctionDescription } from ".";
interface OracleMockInterface extends Interface {
    functions: {
        price: TypedFunctionDescription<{
            encode([]: []): string;
        }>;
        read: TypedFunctionDescription<{
            encode([]: []): string;
        }>;
        updatePrice: TypedFunctionDescription<{
            encode([_newPrice]: [BigNumberish]): string;
        }>;
    };
    events: {};
}
export declare class OracleMock extends Contract {
    connect(signerOrProvider: Signer | Provider | string): OracleMock;
    attach(addressOrName: string): OracleMock;
    deployed(): Promise<OracleMock>;
    on(event: EventFilter | string, listener: Listener): OracleMock;
    once(event: EventFilter | string, listener: Listener): OracleMock;
    addListener(eventName: EventFilter | string, listener: Listener): OracleMock;
    removeAllListeners(eventName: EventFilter | string): OracleMock;
    removeListener(eventName: any, listener: Listener): OracleMock;
    interface: OracleMockInterface;
    functions: {
        price(): Promise<BigNumber>;
        read(): Promise<BigNumber>;
        updatePrice(_newPrice: BigNumberish, overrides?: TransactionOverrides): Promise<ContractTransaction>;
    };
    price(): Promise<BigNumber>;
    read(): Promise<BigNumber>;
    updatePrice(_newPrice: BigNumberish, overrides?: TransactionOverrides): Promise<ContractTransaction>;
    filters: {};
    estimate: {
        price(): Promise<BigNumber>;
        read(): Promise<BigNumber>;
        updatePrice(_newPrice: BigNumberish): Promise<BigNumber>;
    };
}
export {};