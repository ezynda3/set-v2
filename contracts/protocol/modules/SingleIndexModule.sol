/*
    Copyright 2020 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { AddressArrayUtils } from "../../lib/AddressArrayUtils.sol";
import { IController } from "../../interfaces/IController.sol";
import { Invoke } from "../lib/Invoke.sol";
import { ISetToken } from "../../interfaces/ISetToken.sol";
import { IWETH } from "../../interfaces/external/IWETH.sol";
import { ModuleBase } from "../lib/ModuleBase.sol";
import { Position } from "../lib/Position.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";


/**
 * @title SingleIndexModule
 * @author Set Protocol
 *
 * Smart contract that facilitates rebalances for indices. Manager can set target unit amounts, max trade sizes, the
 * exchange to trade on, and the cool down period between trades (on a per asset basis). As currently constructed
 * the module only works for one Set at a time.
 *
 * SECURITY ASSUMPTION:
 *  - Works with following modules: StreamingFeeModule, BasicIssuanceModule (any other module additions to Sets using
      this module need to be examined separately)
 */
contract SingleIndexModule is ModuleBase, ReentrancyGuard {
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using Position for uint256;
    using Math for uint256;
    using Position for ISetToken;
    using Invoke for ISetToken;
    using AddressArrayUtils for address[];

    /* ============ Structs ============ */

    struct AssetTrade {
        uint256 targetUnit;              // Target unit for the asset during current rebalance period
        uint256 maxSize;                 // Max trade size in precise units
        uint256 coolOffPeriod;           // Required time between trades for the asset
        uint256 lastTradeTimestamp;      // Timestamp of last trade
        uint256 exchange;                // Integer representing ID of exchange to use
    }

    /* ============ Events ============ */

    event TargetUnitsUpdated(IERC20 indexed _component, uint256 _newUnit, uint256 _positionMultiplier);
    event TradeMaximumUpdated(IERC20 indexed _component, uint256 _newMaximum);
    event AssetExchangeUpdated(IERC20 indexed _component, uint256 _newExchange);
    event CoolOffPeriodUpdated(IERC20 indexed _component, uint256 _newCoolOffPeriod);
    event TraderStatusUpdated(address indexed _trader, bool _status);
    event AnyoneTradeUpdated(bool indexed _status);
    event TradeExecuted(
        address indexed _executor,
        address indexed _sellComponent,
        address indexed _buyComponent,
        uint256 _amountSold,
        uint256 _amountBought
    );

    /* ============ Constants ============ */

    uint256 private constant UNISWAP_ID = 0;        // ID reference to Uniswap router
    uint256 private constant SUSHISWAP_ID = 1;      // ID reference to Sushiswap router
    uint256 private constant BALANCER_ID = 2;       // ID reference to Balancer router

    uint256 private constant TARGET_RAISE_LIMIT = 25 * 1e14;    // 25 bps in preciseUnits
    uint256 private constant BALANCER_POOL_LIMIT = 3;           // Amount of pools examined when fetching quote

    string private constant UNISWAP_OUT = "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)";
    string private constant UNISWAP_IN = "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)";
    string private constant BALANCER_OUT = "smartSwapExactOut(address,address,uint256,uint256,uint256)";
    string private constant BALANCER_IN = "smartSwapExactIn(address,address,uint256,uint256,uint256)";

    /* ============ State Variables ============ */

    mapping(IERC20 => AssetTrade) public assetInfo;         // Mapping of component to component restrictions
    IERC20[] public rebalanceComponents;                    // Components having units updated during current rebalance
    uint256 public positionMultiplier;                      // Position multiplier when current rebalance units were devised
    mapping(address => bool) public tradeAllowList;         // Mapping of addresses allowed to call trade()
    bool public anyoneTrade;                                // Toggles on or off skipping the tradeAllowList
    ISetToken public index;                                 // Index being managed with contract
    IWETH public weth;                                      // Weth contract address
    address public uniswapRouter;                           // Uniswap router address
    address public sushiswapRouter;                         // Sushiswap router address
    address public balancerProxy;                           // Balancer exchange proxy address

    /* ============ Modifiers ============ */

    modifier onlyAllowedTrader(address _caller) {
        require(_isAllowedTrader(_caller), "Address not permitted to trade");
        _;
    }

    /* ============ Constructor ============ */

    constructor(
        IController _controller,
        IWETH _weth,
        address _uniswapRouter,
        address _sushiswapRouter,
        address _balancerProxy
    )
        public
        ModuleBase(_controller)
    {
        weth = _weth;
        uniswapRouter = _uniswapRouter;
        sushiswapRouter = _sushiswapRouter;
        balancerProxy = _balancerProxy;
    }

    /**
     * MANAGER ONLY: Set new target units, zeroing out any units for components being removed from index. Log position multiplier to
     * adjust target units in case fees are accrued. Validate that weth is not a part of the new allocation and that all components
     * in current allocation are in _components array.
     *
     * @param _components               Array of components in new allocation plus any components removed from old allocation
     * @param _targetUnits              Array of target units at end of rebalance, maps to same index of component, if component
     *                                      being removed set to 0.
     * @param _positionMultiplier       Position multiplier when target units were calculated, needed in order to adjust target units
     *                                      if fees accrued
     */
    function startRebalance(
        IERC20[] calldata _components,
        uint256[] calldata _targetUnits,
        uint256 _positionMultiplier
    )
        external
        onlyManagerAndValidSet(index)
    {
        _validateArrays(_components, _targetUnits);
        
        address[] memory currentComponents = index.getComponents();

        for (uint256 i = 0; i < _components.length; i++) {
            IERC20 component = _components[i];
            uint256 targetUnit = _targetUnits[i];

            require(address(component) != address(weth), "WETH cannot be an index component");
            assetInfo[component].targetUnit = targetUnit;

            if (currentComponents.contains(address(component))) {
                currentComponents = currentComponents.remove(address(component));
            }

            emit TargetUnitsUpdated(component, targetUnit, _positionMultiplier);
        }

        require(currentComponents.length == 0, "New allocation must have target for all old components");

        rebalanceComponents = _components;
        positionMultiplier = _positionMultiplier;
    }

    /**
     * ACCESS LIMITED: Only approved addresses can call if anyoneTrade is false. Determines trade size
     * and direction and swaps into or out of WETH on exchange specified by manager.
     *
     * @param _component            Component to trade
     */
    function trade(IERC20 _component) external nonReentrant onlyAllowedTrader(msg.sender) virtual {
        require(msg.sender == tx.origin, "Caller must be EOA Address");

        _validateTradeParameters(_component);

        (
            bool isBuy,
            uint256 tradeAmount
        ) = _calculateTradeSizeAndDirection(_component);

        if (isBuy) {
            _buyUnderweight(_component, tradeAmount);
        } else {
            _sellOverweight(_component, tradeAmount);
        }
    }

    /**
     * ACCESS LIMITED: Only approved addresses can call if anyoneTrade is false. Only callable when 1) there are no
     * more components to be sold and, 2) entire remaining WETH amount can be traded such that resulting inflows won't
     * exceed components maxTradeSize nor overshoot the target unit. To be used near the end of rebalances when a
     * component's calculated trade size is greater in value than remaining WETH.
     *
     * @param _component            Component to trade
     */
    function tradeRemainingWETH(IERC20 _component) external nonReentrant onlyAllowedTrader(msg.sender) virtual {
        require(msg.sender == tx.origin, "Caller must be EOA Address");
        require(_noTokensToSell(), "Must sell all sellable tokens before can be called");

        _validateTradeParameters(_component);

        (, uint256 tradeLimit) = _calculateTradeSizeAndDirection(_component);

        uint256 preTradeComponentAmount = _component.balanceOf(address(index));
        uint256 preTradeWethAmount = weth.balanceOf(address(index));

        _executeTrade(address(weth), address(_component), true, preTradeWethAmount, assetInfo[_component].exchange);

        (,
            uint256 componentTradeSize
        ) = _updatePositionState(address(weth), address(_component), preTradeWethAmount, preTradeComponentAmount);

        require(componentTradeSize < tradeLimit, "Component amount exceeds trade size limit");

        assetInfo[_component].lastTradeTimestamp = block.timestamp;
    }

    /**
     * ACCESS LIMITED: For situation where all target units met and remaining WETH, uniformly raise targets by same
     * percentage in order to allow further trading. Can be called multiple times if necessary, increase should be
     * small in order to reduce tracking error.
     */
    function raiseAssetTargets() external nonReentrant onlyAllowedTrader(msg.sender) virtual {
        require(
            _allTargetsMet() && index.getDefaultPositionRealUnit(address(weth)) > 0,
            "Targets must be met and ETH remaining in order to raise target"
        );

        positionMultiplier = positionMultiplier.preciseDiv(PreciseUnitMath.preciseUnit().add(TARGET_RAISE_LIMIT));
    }

    /**
     * MANAGER ONLY: Set trade maximums for passed components
     *
     * @param _components            Array of components
     * @param _tradeMaximums         Array of trade maximums mapping to correct component
     */
    function setTradeMaximums(
        IERC20[] calldata _components,
        uint256[] calldata _tradeMaximums
    )
        external
        onlyManagerAndValidSet(index)
    {
        _validateArrays(_components, _tradeMaximums);

        for (uint256 i = 0; i < _components.length; i++) {
            assetInfo[_components[i]].maxSize = _tradeMaximums[i];
            emit TradeMaximumUpdated(_components[i], _tradeMaximums[i]);
        }
    }

    /**
     * MANAGER ONLY: Set exchange for passed components
     *
     * @param _components        Array of components
     * @param _exchanges         Array of exchanges mapping to correct component, uint256 used to signify exchange
     */
    function setExchanges(
        IERC20[] calldata _components,
        uint256[] calldata _exchanges
    )
        external
        onlyManagerAndValidSet(index)
    {
        _validateArrays(_components, _exchanges);

        for (uint256 i = 0; i < _components.length; i++) {
            uint256 exchange = _exchanges[i];
            require(exchange < 3, "Unrecognized exchange identifier");
            assetInfo[_components[i]].exchange = _exchanges[i];

            emit AssetExchangeUpdated(_components[i], exchange);
        }
    }

    /**
     * MANAGER ONLY: Set exchange for passed components
     *
     * @param _components           Array of components
     * @param _coolOffPeriods       Array of cool off periods to correct component
     */
    function setCoolOffPeriods(
        IERC20[] calldata _components,
        uint256[] calldata _coolOffPeriods
    )
        external
        onlyManagerAndValidSet(index)
    {
        _validateArrays(_components, _coolOffPeriods);

        for (uint256 i = 0; i < _components.length; i++) {
            assetInfo[_components[i]].coolOffPeriod = _coolOffPeriods[i];
            emit CoolOffPeriodUpdated(_components[i], _coolOffPeriods[i]);
        }
    }

    /**
     * MANAGER ONLY: Toggle ability for passed addresses to trade from current state 
     *
     * @param _traders           Array trader addresses to toggle status
     */
    function updateTraderStatus(address[] calldata _traders) external onlyManagerAndValidSet(index) {
        require(_traders.length > 0, "Array length must be > 0");
        for (uint256 i = 0; i < _traders.length; i++) {
            address trader = _traders[i];
            tradeAllowList[trader] = !tradeAllowList[trader];
            emit TraderStatusUpdated(trader, tradeAllowList[trader]);
        }
    }

    /**
     * MANAGER ONLY: Toggle whether anyone can trade, bypassing the traderAllowList 
     */
    function updateAnyoneTrade() external onlyManagerAndValidSet(index) {
        anyoneTrade = !anyoneTrade;
        emit AnyoneTradeUpdated(anyoneTrade);
    }

    /**
     * MANAGER ONLY: Set target units to current units and last trade to current timestamp. Initialize module.
     *
     * @param _index            Address of index being used for this Set
     */
    function initialize(ISetToken _index)
        external
        onlySetManager(_index, msg.sender)
        onlyValidAndPendingSet(_index)
    {
        require(address(index) == address(0), "Module already in use");

        ISetToken.Position[] memory positions = _index.getPositions();

        for (uint256 i = 0; i < positions.length; i++) {
            assetInfo[IERC20(positions[i].component)].targetUnit = positions[i].unit.toUint256();
            assetInfo[IERC20(positions[i].component)].lastTradeTimestamp = block.timestamp;
        }

        _index.initializeModule();
        index = _index;
    }

    function removeModule() external override {
        require(msg.sender == address(index), "Caller must be index");
    }

    /* ============ Getter Functions ============ */

    /**
     * Get target units for passed components, normalized to current positionMultiplier.
     *
     * @param _components           Array of components to get target units for
     * @return                      Array of targetUnits mapping to passed components
     */
    function getTargetUnits(IERC20[] calldata _components) external view returns(uint256[] memory) {
        uint256 currentPositionMultiplier = index.positionMultiplier().toUint256();
        
        uint256[] memory targetUnits = new uint256[](_components.length);
        for (uint256 i = 0; i < _components.length; i++) {
            targetUnits[i] = _normalizeTargetUnit(_components[i], currentPositionMultiplier);
        }

        return targetUnits;
    }

    /* ============ Internal Functions ============ */

    /**
     * Validate that enough time has elapsed since component's last trade and component isn't WETH.
     */
    function _validateTradeParameters(IERC20 _component) internal view virtual {
        AssetTrade memory componentInfo = assetInfo[_component];
        require(
            componentInfo.lastTradeTimestamp.add(componentInfo.coolOffPeriod) <= block.timestamp,
            "Cool off period has not elapsed."
        );
        require(address(_component) != address(weth), "Component cannot be WETH");
    }

    /**
     * Calculate trade size and whether trade is buy or sell. Trade size is the minimum of the max size and components left to trade.
     * Reverts if target quantity is already met. Target unit is adjusted based on ratio of position multiplier when target was defined
     * and the current positionMultiplier.
     */
    function _calculateTradeSizeAndDirection(IERC20 _component) internal view returns (bool, uint256) {
        uint256 totalSupply = index.totalSupply();

        uint256 componentMaxSize = assetInfo[_component].maxSize;
        uint256 currentPositionMultiplier = index.positionMultiplier().toUint256();

        uint256 currentNotional = totalSupply.getDefaultTotalNotional(
            index.getDefaultPositionRealUnit(address(_component)).toUint256()
        );
        uint256 targetNotional = totalSupply.getDefaultTotalNotional(_normalizeTargetUnit(_component, currentPositionMultiplier));

        require(targetNotional != currentNotional, "Target already met");

        return targetNotional > currentNotional ? (true, componentMaxSize.min(targetNotional.sub(currentNotional))) :
            (false, componentMaxSize.min(currentNotional.sub(targetNotional)));
    }

    /**
     * Buy an underweight asset by selling an unfixed amount of WETH for a fixed amount of the component.
     */
    function _buyUnderweight(IERC20 _component, uint256 _amount) internal {
        uint256 preTradeBuyComponentAmount = _component.balanceOf(address(index));
        uint256 preTradeSellComponentAmount = weth.balanceOf(address(index));

        _executeTrade(address(weth), address(_component), false, _amount, assetInfo[_component].exchange);

        _updatePositionState(address(weth), address(_component), preTradeSellComponentAmount, preTradeBuyComponentAmount);

        assetInfo[_component].lastTradeTimestamp = block.timestamp;
    }

    /**
     * Sell an overweight asset by selling a fixed amount of component for an unfixed amount of WETH.
     */
    function _sellOverweight(IERC20 _component, uint256 _amount) internal {
        uint256 preTradeBuyComponentAmount = weth.balanceOf(address(index));
        uint256 preTradeSellComponentAmount = _component.balanceOf(address(index));

        _executeTrade(address(_component), address(weth), true, _amount, assetInfo[_component].exchange);

        _updatePositionState(address(_component), address(weth), preTradeSellComponentAmount, preTradeBuyComponentAmount);

        assetInfo[_component].lastTradeTimestamp = block.timestamp;
    }

    /**
     * Determine parameters for trade and invoke trade on index using correct exchange.
     */
    function _executeTrade(
        address _sellComponent,
        address _buyComponent,
        bool _fixIn,
        uint256 _amount,
        uint256 _exchange
    )
        internal
        virtual
    {
        uint256 wethBalance = weth.balanceOf(address(index));
        
        (
            address exchangeAddress,
            bytes memory tradeCallData
        ) = _exchange == BALANCER_ID ? _getBalancerTradeData(_sellComponent, _buyComponent, _fixIn, _amount, wethBalance) :
            _getUniswapLikeTradeData(_sellComponent, _buyComponent, _fixIn, _amount, _exchange);

        uint256 approveAmount = _sellComponent == address(weth) ? wethBalance : _amount;
        index.invokeApprove(_sellComponent, exchangeAddress, approveAmount);
        index.invoke(exchangeAddress, 0, tradeCallData);
    }

    /**
     * Update position units on index. Emit event.
     */
    function _updatePositionState(
        address _sellComponent,
        address _buyComponent,
        uint256 _preTradeSellComponentAmount,
        uint256 _preTradeBuyComponentAmount
    )
        internal
        returns (uint256 sellAmount, uint256 buyAmount)
    {
        uint256 totalSupply = index.totalSupply();

        (uint256 postTradeSellComponentAmount,,) = index.calculateAndEditDefaultPosition(
            _sellComponent,
            totalSupply,
            _preTradeSellComponentAmount
        );
        (uint256 postTradeBuyComponentAmount,,) = index.calculateAndEditDefaultPosition(
            _buyComponent,
            totalSupply,
            _preTradeBuyComponentAmount
        );

        sellAmount = _preTradeSellComponentAmount.sub(postTradeSellComponentAmount);
        buyAmount = postTradeBuyComponentAmount.sub(_preTradeBuyComponentAmount);

        emit TradeExecuted(
            msg.sender,
            _sellComponent,
            _buyComponent,
            sellAmount,
            buyAmount
        );
    }

    /**
     * Create Balancer trade call data
     */
    function _getBalancerTradeData(
        address _sellComponent,
        address _buyComponent,
        bool _fixIn,
        uint256 _amount,
        uint256 _maxOut
    )
        internal
        view
        returns(address, bytes memory)
    {
        address exchangeAddress = balancerProxy;
        (
            string memory functionSignature,
            uint256 limit
        ) = _fixIn ? (BALANCER_IN, 1) : (BALANCER_OUT, _maxOut);

        bytes memory tradeCallData = abi.encodeWithSignature(
            functionSignature,
            _sellComponent,
            _buyComponent,
            _amount,
            limit,
            BALANCER_POOL_LIMIT
        );

        return (exchangeAddress, tradeCallData);       
    }

    /**
     * Determine whether exchange to call is Uniswap or Sushiswap and generate necessary call data.
     */
    function _getUniswapLikeTradeData(
        address _sellComponent,
        address _buyComponent,
        bool _fixIn,
        uint256 _amount,
        uint256 _exchange
    )
        internal
        view
        returns(address, bytes memory)
    {
        address exchangeAddress = _exchange == UNISWAP_ID ? uniswapRouter : sushiswapRouter;
        
        string memory functionSignature;
        address[] memory path = new address[](2);
        uint256 limit;
        if (_fixIn) {
            functionSignature = UNISWAP_IN;
            limit = 1;
        } else {
            functionSignature = UNISWAP_OUT;
            limit = PreciseUnitMath.maxUint256();
        }
        path[0] = _sellComponent;
        path[1] = _buyComponent;
        
        bytes memory tradeCallData = abi.encodeWithSignature(
            functionSignature,
            _amount,
            limit,
            path,
            address(index),
            now.add(180)
        );

        return (exchangeAddress, tradeCallData);
    }

    /**
     * Check if there are any more tokens to sell.
     */
    function _noTokensToSell() internal view returns (bool) {
        uint256 currentPositionMultiplier = index.positionMultiplier().toUint256();
        for (uint256 i = 0; i < rebalanceComponents.length; i++) {
            IERC20 component = rebalanceComponents[i];
            bool canSell = _normalizeTargetUnit(component, currentPositionMultiplier) < index.getDefaultPositionRealUnit(
                address(component)
            ).toUint256();
            if (canSell) { return false; }
        }
        return true;
    }

    /**
     * Check if all targets are met
     */
    function _allTargetsMet() internal view returns (bool) {
        uint256 currentPositionMultiplier = index.positionMultiplier().toUint256();
        for (uint256 i = 0; i < rebalanceComponents.length; i++) {
            IERC20 component = rebalanceComponents[i];
            bool targetUnmet = _normalizeTargetUnit(component, currentPositionMultiplier) != index.getDefaultPositionRealUnit(
                address(component)
            ).toUint256();
            if (targetUnmet) { return false; }
        }
        return true;
    }

    /**
     * Normalize target unit to current position multiplier in case fees have been accrued.
     */
    function _normalizeTargetUnit(IERC20 _component, uint256 _currentPositionMultiplier) internal view returns(uint256) {
        return assetInfo[_component].targetUnit.mul(_currentPositionMultiplier).div(positionMultiplier);
    }

    /**
     * Determine if passed address is allowed to call trade. If anyoneTrade set to true anyone can call otherwise needs to be approved.
     */
    function _isAllowedTrader(address _caller) internal view virtual returns (bool) {
        return anyoneTrade ? true : tradeAllowList[_caller];
    }

    /**
     * Validate arrays are of equal length and not empty.
     */
    function _validateArrays(IERC20[] calldata _components, uint256[] calldata _data) internal pure {
        require(_components.length == _data.length, "Array length mismatch");
        require(_components.length > 0, "Array length must be > 0");
    }
}