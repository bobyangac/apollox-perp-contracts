pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "../contracts/diamond/interfaces/ITradingConfig.sol";

contract PlaceMarketWithPositionCleaning {
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;

    event Result(address indexed sender, uint80 indexed inputQty, uint80 indexed remainQty);

    function openMarketTradeWithPositionCleaning(ITradingPortal.OpenDataInput calldata openDataInput) external {
        uint80 originQty = openDataInput.qty;

        ITradingReader.Position[] memory positions = ITradingReader(address(contract_address)).getPositions(
            address(msg.sender), address(openDataInput.pairBase)
        );

        ITradingReader.Position[] memory longPositions;
        ITradingReader.Position[] memory shortPositions;

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isLong) {
                longPositions = appendPosition(longPositions, positions[i]);
            } else {
                shortPositions = appendPosition(shortPositions, positions[i]);
            }
        }

        uint80 remainQty = 0;
        if (openDataInput.isLong) {
            // Close positions with worst entry price first.
            shortPositions = sortPositionsByEntryPriceAscend(shortPositions);
            remainQty = closePositionsFirst(openDataInput.qty, shortPositions);
        } else {
            // Close positions with worst entry price first.
            longPositions = sortPositionsByEntryPriceDescend(longPositions);
            remainQty = closePositionsFirst(openDataInput.qty, longPositions);
        }

        // Place new order with remaining qty.
        if (remainQty > 0) {
            ITradingConfig.TradingConfig memory tc = ITradingConfig(address(contract_address)).getTradingConfig();

            uint256 notionalUsd = openDataInput.price * openDataInput.qty;

            // 5% buffer for min notional
            if (notionalUsd < (tc.minNotionalUsd * 105) / 100) {
                emit Result(msg.sender, originQty, remainQty);
            } else {
                IBook.OpenDataInput memory openDataInputNew = IBook.OpenDataInput({
                    pairBase: openDataInput.pairBase,
                    isLong: openDataInput.isLong,
                    tokenIn: openDataInput.tokenIn,
                    amountIn: openDataInput.amountIn,
                    qty: remainQty,
                    price: openDataInput.price,
                    stopLoss: openDataInput.stopLoss,
                    takeProfit: openDataInput.takeProfit,
                    broker: openDataInput.broker
                });

                ITradingPortal(address(contract_address)).openMarketTrade(openDataInputNew);
                emit Result(msg.sender, originQty, 0);
            }
        }
    }

    // closePositionsFirst close the existing postions first, and return the remaining qty that needs to be placed as new order.
    function closePositionsFirst(uint80 qty, ITradingReader.Position[] memory positions)
        internal
        returns (uint80 remainQty)
    {
    
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].qty > qty) {
                continue;
            } else {
                ITradingPortal(address(contract_address)).closeTrade(positions[i].positionHash);
                qty -= positions[i].qty;
            }
        }
        return qty;
    }

    function appendPosition(ITradingReader.Position[] memory arr, ITradingReader.Position memory pos)
        internal
        pure
        returns (ITradingReader.Position[] memory)
    {
        ITradingReader.Position[] memory newArr = new ITradingReader.Position[](arr.length + 1);
        for (uint256 i = 0; i < arr.length; i++) {
            newArr[i] = arr[i];
        }
        newArr[arr.length] = pos;
        return newArr;
    }

    function sortPositionsByEntryPriceAscend(ITradingReader.Position[] memory positions)
        internal
        pure
        returns (ITradingReader.Position[] memory)
    {
        uint256 n = positions.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (positions[j].entryPrice > positions[j + 1].entryPrice) {
                    ITradingReader.Position memory temp = positions[j];
                    positions[j] = positions[j + 1];
                    positions[j + 1] = temp;
                }
            }
        }

        return positions;
    }

    function sortPositionsByEntryPriceDescend(ITradingReader.Position[] memory positions)
        internal
        pure
        returns (ITradingReader.Position[] memory)
    {
        uint256 n = positions.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (positions[j].entryPrice < positions[j + 1].entryPrice) {
                    ITradingReader.Position memory temp = positions[j];
                    positions[j] = positions[j + 1];
                    positions[j + 1] = temp;
                }
            }
        }

        return positions;
    }
}
