/* Generated by ts-generator ver. 0.0.8 */
/* tslint:disable */

import { Contract, Signer } from "ethers";
import { Provider } from "ethers/providers";

import { IStreamingFeeModule } from "./IStreamingFeeModule";

export class IStreamingFeeModuleFactory {
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IStreamingFeeModule {
    return new Contract(address, _abi, signerOrProvider) as IStreamingFeeModule;
  }
}

const _abi = [
  {
    inputs: [
      {
        internalType: "contract ISetToken",
        name: "_setToken",
        type: "address"
      }
    ],
    name: "feeStates",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "feeRecipient",
            type: "address"
          },
          {
            internalType: "uint256",
            name: "maxStreamingFeePercentage",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "streamingFeePercentage",
            type: "uint256"
          },
          {
            internalType: "uint256",
            name: "lastStreamingFeeTimestamp",
            type: "uint256"
          }
        ],
        internalType: "struct StreamingFeeModule.FeeState",
        name: "",
        type: "tuple"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract ISetToken",
        name: "_setToken",
        type: "address"
      }
    ],
    name: "getFee",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ],
    stateMutability: "view",
    type: "function"
  }
];