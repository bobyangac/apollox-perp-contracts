// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../security/OnlySelf.sol";
import "../interfaces/ITradingCore.sol";
import "../interfaces/IPairsManager.sol";
import "../interfaces/ITradingPortal.sol";
import "../libraries/LibTradingCore.sol";
import "../libraries/LibAccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ZERO, ONE, UC, uc, into} from "unchecked-counter/src/UC.sol";

contract TradingCoreFacet is ITradingCore, OnlySelf {

    using SignedMath for int256;

    function getPairQty(address pairBase) external view override returns (PairQty memory) {
        ITradingCore.PairPositionInfo memory ppi = LibTradingCore.tradingCoreStorage().pairPositionInfos[pairBase];
        return PairQty(ppi.longQty, ppi.shortQty);
    }

    function slippagePrice(address pairBase, uint256 marketPrice, uint256 qty, bool isLong) external view returns (uint256) {
        PairPositionInfo memory ppi = LibTradingCore.tradingCoreStorage().pairPositionInfos[pairBase];
        return slippagePrice(
            PairQty(ppi.longQty, ppi.shortQty), IPairsManager(address(this)).getPairSlippageConfig(pairBase), marketPrice, qty, isLong
        );
    }

    function slippagePrice(
        PairQty memory pairQty,
        IPairsManager.SlippageConfig memory sc,
        uint256 marketPrice, uint256 qty, bool isLong
    ) public pure override returns (uint256) {
        if (isLong) {
            uint slippage = sc.slippageLongP;
            if (sc.slippageType == IPairsManager.SlippageType.ONE_PERCENT_DEPTH) {
                // slippage = (longQty + qty) * price / depthAboveUsd
                slippage = (pairQty.longQty + qty) * marketPrice * 1e4 / sc.onePercentDepthAboveUsd;
            }
            return marketPrice * (1e4 + slippage) / 1e4;
        } else {
            uint slippage = sc.slippageShortP;
            if (sc.slippageType == IPairsManager.SlippageType.ONE_PERCENT_DEPTH) {
                // slippage = (shortQty + qty) * price / depthBelowUsd
                slippage = (pairQty.shortQty + qty) * marketPrice * 1e4 / sc.onePercentDepthBelowUsd;
            }
            return marketPrice * (1e4 - slippage) / 1e4;
        }
    }

    function triggerPrice(address pairBase, uint256 limitPrice, uint256 qty, bool isLong) external view returns (uint256) {
        PairPositionInfo memory ppi = LibTradingCore.tradingCoreStorage().pairPositionInfos[pairBase];
        return triggerPrice(
            PairQty(ppi.longQty, ppi.shortQty), IPairsManager(address(this)).getPairSlippageConfig(pairBase), limitPrice, qty, isLong
        );
    }

    function triggerPrice(
        PairQty memory pairQty,
        IPairsManager.SlippageConfig memory sc,
        uint256 limitPrice, uint256 qty, bool isLong
    ) public pure override returns (uint256) {
        if (isLong) {
            uint slippage = sc.slippageLongP;
            if (sc.slippageType == IPairsManager.SlippageType.ONE_PERCENT_DEPTH) {
                // slippage = (longQty + qty) * price / depthAboveUsd
                slippage = (pairQty.longQty + qty) * limitPrice * 1e4 / sc.onePercentDepthAboveUsd;
            }
            return limitPrice * (1e4 - slippage) / 1e4;
        } else {
            uint slippage = sc.slippageShortP;
            if (sc.slippageType == IPairsManager.SlippageType.ONE_PERCENT_DEPTH) {
                // slippage = (shortQty + qty) * price / depthBelowUsd
                slippage = (pairQty.shortQty + qty) * limitPrice * 1e4 / sc.onePercentDepthBelowUsd;
            }
            return limitPrice * (1e4 + slippage) / 1e4;
        }
    }

    function lastLongAccFundingFeePerShare(address pairBase) external view override returns (int256 longAccFundingFeePerShare) {
        PairPositionInfo memory ppi = LibTradingCore.tradingCoreStorage().pairPositionInfos[pairBase];
        longAccFundingFeePerShare = ppi.longAccFundingFeePerShare;
        if (block.number > ppi.lastFundingFeeBlock) {
            int256 fundingFeeR = LibTradingCore.fundingFeeRate(ppi, pairBase);
            longAccFundingFeePerShare += fundingFeeR * (- 1) * int256(block.number - ppi.lastFundingFeeBlock);
        }
        return longAccFundingFeePerShare;
    }

    function updatePairPositionInfo(
        address pairBase, uint userPrice, uint marketPrice, uint qty, bool isLong, bool isOpen
    ) external onlySelf override returns (int256 longAccFundingFeePerShare){
        LibTradingCore.TradingCoreStorage storage tcs = LibTradingCore.tradingCoreStorage();
        PairPositionInfo storage ppi = tcs.pairPositionInfos[pairBase];
        if (ppi.longQty > 0 || ppi.shortQty > 0) {
            uint256 lpReceiveFundingFeeUsd = _updateFundingFee(ppi, pairBase, marketPrice);
            if (lpReceiveFundingFeeUsd > 0) {
                ITradingPortal(address(this)).settleLpFundingFee(lpReceiveFundingFeeUsd);
            }
        } else {
            ppi.lastFundingFeeBlock = block.number;
        }
        longAccFundingFeePerShare = ppi.longAccFundingFeePerShare;
        _updatePairQtyAndAvgPrice(tcs, ppi, pairBase, qty, userPrice, isOpen, isLong);
        emit UpdatePairPositionInfo(
            pairBase, ppi.lastFundingFeeBlock, ppi.longQty, ppi.shortQty,
            longAccFundingFeePerShare, ppi.lpAveragePrice
        );
        return longAccFundingFeePerShare;
    }
    
    function _updateFundingFee(
        ITradingCore.PairPositionInfo storage ppi, address pairBase, uint256 marketPrice
    ) private returns (uint256 lpReceiveFundingFeeUsd){
        int256 oldLongAccFundingFeePerShare = ppi.longAccFundingFeePerShare;
        bool needTransfer = _updateAccFundingFeePerShare(ppi, pairBase);
        if (needTransfer) {
            int256 longReceiveFundingFeeUsd = int256(ppi.longQty * marketPrice) * (ppi.longAccFundingFeePerShare - oldLongAccFundingFeePerShare) / 1e18;
            int256 shortReceiveFundingFeeUsd = int256(ppi.shortQty * marketPrice) * (ppi.longAccFundingFeePerShare - oldLongAccFundingFeePerShare) * (- 1) / 1e18;
            if (ppi.longQty > ppi.shortQty) {
                require(
                    (shortReceiveFundingFeeUsd == 0 && longReceiveFundingFeeUsd == 0) ||
                    longReceiveFundingFeeUsd < 0 && shortReceiveFundingFeeUsd >= 0 && longReceiveFundingFeeUsd.abs() > shortReceiveFundingFeeUsd.abs(),
                    "LibTrading: Funding fee calculation error. [LONG]"
                );
                lpReceiveFundingFeeUsd = (longReceiveFundingFeeUsd + shortReceiveFundingFeeUsd).abs();
            } else {
                require(
                    (shortReceiveFundingFeeUsd == 0 && longReceiveFundingFeeUsd == 0) ||
                    (shortReceiveFundingFeeUsd < 0 && longReceiveFundingFeeUsd >= 0 && shortReceiveFundingFeeUsd.abs() > longReceiveFundingFeeUsd.abs()),
                    "LibTrading: Funding fee calculation error. [SHORT]"
                );
                lpReceiveFundingFeeUsd = (shortReceiveFundingFeeUsd + longReceiveFundingFeeUsd).abs();
            }
        }
        return lpReceiveFundingFeeUsd;
    }

    function _updateAccFundingFeePerShare(
        ITradingCore.PairPositionInfo storage ppi, address pairBase
    ) private returns (bool){
        if (block.number <= ppi.lastFundingFeeBlock) {
            return false;
        }
        int256 fundingFeeR = LibTradingCore.fundingFeeRate(ppi, pairBase);
        // (ppi.longQty > ppi.shortQty) & (fundingFeeRate > 0) & (Long - money <==> Short + money) & (longAcc < 0)
        // (ppi.longQty < ppi.shortQty) & (fundingFeeRate < 0) & (Long + money <==> Short - money) & (longAcc > 0)
        // (ppi.longQty == ppi.shortQty) & (fundingFeeRate == 0)
        ppi.longAccFundingFeePerShare += fundingFeeR * (- 1) * int256(block.number - ppi.lastFundingFeeBlock);
        ppi.lastFundingFeeBlock = block.number;
        return true;
    }

    function _updatePairQtyAndAvgPrice(
        LibTradingCore.TradingCoreStorage storage tcs,
        ITradingCore.PairPositionInfo storage ppi,
        address pairBase, uint256 qty,
        uint256 userPrice, bool isOpen, bool isLong
    ) private {
        if (isOpen) {
            if (ppi.longQty == 0 && ppi.shortQty == 0) {
                ppi.pairBase = pairBase;
                ppi.pairIndex = uint16(tcs.hasPositionPairs.length);
                tcs.hasPositionPairs.push(pairBase);
            }
            if (isLong) {
                // LP Increase position
                if (ppi.longQty >= ppi.shortQty) {
                    ppi.lpAveragePrice = uint64((ppi.lpAveragePrice * (ppi.longQty - ppi.shortQty) + userPrice * qty) / (ppi.longQty + qty - ppi.shortQty));
                }
                // LP Reverse open position
                else if (ppi.longQty < ppi.shortQty && ppi.longQty + qty > ppi.shortQty) {
                    ppi.lpAveragePrice = uint64(userPrice);
                }
                // LP position == 0
                else if (ppi.longQty < ppi.shortQty && ppi.longQty + qty == ppi.shortQty) {
                    ppi.lpAveragePrice = 0;
                }
                // LP Reduce position, No change in average price
                ppi.longQty += qty;
            } else {
                // LP Increase position
                if (ppi.shortQty >= ppi.longQty) {
                    ppi.lpAveragePrice = uint64((ppi.lpAveragePrice * (ppi.shortQty - ppi.longQty) + userPrice * qty) / (ppi.shortQty + qty - ppi.longQty));
                }
                // LP Reverse open position
                else if (ppi.shortQty < ppi.longQty && ppi.shortQty + qty > ppi.longQty) {
                    ppi.lpAveragePrice = uint64(userPrice);
                }
                // LP position == 0
                else if (ppi.shortQty < ppi.longQty && ppi.shortQty + qty == ppi.longQty) {
                    ppi.lpAveragePrice = 0;
                }
                // LP Reduce position, No change in average price
                ppi.shortQty += qty;
            }
        } else {
            if (isLong) {
                // LP Reduce position, No change in average price
                // if (ppi.longQty > ppi.shortQty && ppi.longQty - qty > ppi.shortQty)
                // LP position == 0
                if (ppi.longQty > ppi.shortQty && ppi.longQty - qty == ppi.shortQty) {
                    ppi.lpAveragePrice = 0;
                }
                // LP Reverse open position
                else if (ppi.longQty > ppi.shortQty && ppi.longQty - qty < ppi.shortQty) {
                    ppi.lpAveragePrice = uint64(userPrice);
                }
                // LP Increase position
                else if (ppi.longQty <= ppi.shortQty) {
                    ppi.lpAveragePrice = uint64((ppi.lpAveragePrice * (ppi.shortQty - ppi.longQty) + userPrice * qty) / (ppi.shortQty - ppi.longQty + qty));
                }
                ppi.longQty -= qty;
            } else {
                // LP Reduce position, No change in average price
                // if (ppi.longQty > ppi.shortQty && ppi.longQty - qty > ppi.shortQty)
                // LP position == 0
                if (ppi.shortQty > ppi.longQty && ppi.shortQty - qty == ppi.longQty) {
                    ppi.lpAveragePrice = 0;
                }
                // LP Reverse open position
                else if (ppi.shortQty > ppi.longQty && ppi.shortQty - qty < ppi.longQty) {
                    ppi.lpAveragePrice = uint64(userPrice);
                }
                // LP Increase position
                else if (ppi.shortQty <= ppi.longQty) {
                    ppi.lpAveragePrice = uint64((ppi.lpAveragePrice * (ppi.longQty - ppi.shortQty) + userPrice * qty) / (ppi.longQty - ppi.shortQty + qty));
                }
                ppi.shortQty -= qty;
            }
            if (ppi.longQty == 0 && ppi.shortQty == 0) {
                address[] storage pairs = tcs.hasPositionPairs;
                uint lastIndex = pairs.length - 1;
                uint removeIndex = ppi.pairIndex;
                if (lastIndex != removeIndex) {
                    address lastPair = pairs[lastIndex];
                    pairs[removeIndex] = lastPair;
                    tcs.pairPositionInfos[lastPair].pairIndex = uint16(removeIndex);
                }
                pairs.pop();
                delete tcs.pairPositionInfos[pairBase];
            }
        }
    }

    function lpUnrealizedPnlUsd() external view override returns (int256 unrealizedPnlUsd) {
        LibTradingCore.TradingCoreStorage storage tcs = LibTradingCore.tradingCoreStorage();
        address[] memory hasPositionPairs = tcs.hasPositionPairs;
        for (UC i = ZERO; i < uc(hasPositionPairs.length); i = i + ONE) {
            address pairBase = hasPositionPairs[i.into()];
            PairPositionInfo memory ppi = tcs.pairPositionInfos[pairBase];
            (uint256 price,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(pairBase);
            int256 lpAvgPrice = int256(uint256(ppi.lpAveragePrice));
            if (ppi.longQty > ppi.shortQty) {// LP Short
                unrealizedPnlUsd += int256(ppi.longQty - ppi.shortQty) * (lpAvgPrice - int256(price));
            } else {// LP Long
                unrealizedPnlUsd += int256(ppi.shortQty - ppi.longQty) * (int256(price) - lpAvgPrice);
            }
        }
        return unrealizedPnlUsd;
    }

    function lpNotionalUsd() external view override returns (uint256 notionalUsd) {
        LibTradingCore.TradingCoreStorage storage tcs = LibTradingCore.tradingCoreStorage();
        address[] memory hasPositionPairs = tcs.hasPositionPairs;
        for (UC i = ZERO; i < uc(hasPositionPairs.length); i = i + ONE) {
            address pairBase = hasPositionPairs[i.into()];
            PairPositionInfo memory ppi = tcs.pairPositionInfos[pairBase];
            (uint256 price,) = IPriceFacade(address(this)).getPriceFromCacheOrOracle(pairBase);
            if (ppi.longQty > ppi.shortQty) {
                notionalUsd += (ppi.longQty - ppi.shortQty) * price;
            } else {
                notionalUsd += (ppi.shortQty - ppi.longQty) * price;
            }
        }
        return notionalUsd;
    }
}
