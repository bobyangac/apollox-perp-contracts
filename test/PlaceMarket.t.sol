pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "../contracts/diamond/interfaces/ITradingConfig.sol";

contract PlaceMarketTest is Test {
    address test_wallet = 0x609F4479A03DF91C635C451835d22cC12C7108C0;
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;
    address eth_usd_address = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address usdt_address = 0x55d398326f99059fF775485246999027B3197955;

    event Result(address indexed sender, uint80 indexed inputQty, uint80 indexed remainQty);

    function testPlaceMarket() public {
        // test open market order input
        IBook.OpenDataInput memory openDataInput = IBook.OpenDataInput({
            pairBase: address(eth_usd_address),
            isLong: true,
            tokenIn: address(usdt_address),
            amountIn: 70000000000000000000,
            qty: 1500000000,
            price: 186006058732,
            stopLoss: 149924846985,
            takeProfit: 327960602781,
            broker: 1
        });

        uint80 originQty = openDataInput.qty;

        ITradingReader.Position[] memory positions = ITradingReader(address(contract_address)).getPositions(
            address(test_wallet), address(0x0000000000000000000000000000000000000000)
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
            shortPositions = sortPositionsByEntryPriceDescend(shortPositions);
            remainQty = closePositionsFirst(openDataInput.qty, shortPositions);
        } else {
            longPositions = sortPositionsByEntryPriceAscend(longPositions);
            remainQty = closePositionsFirst(openDataInput.qty, longPositions);
        }

        if (remainQty > 0) {
            openDataInput.qty = remainQty;

            ITradingConfig.TradingConfig memory tc = ITradingConfig(address(contract_address)).getTradingConfig();

            uint256 notionalUsd = openDataInput.price * openDataInput.qty;
            // 5% buffer for min notional
            if (notionalUsd < (tc.minNotionalUsd * 105) / 100) {
                emit Result(msg.sender, originQty, remainQty);
                return;
            } else {
                ITradingPortal(address(contract_address)).openMarketTrade(openDataInput);
                emit Result(msg.sender, originQty, 0);
            }
        }
    }

    function closePositionsFirst(uint80 qty, ITradingReader.Position[] memory positions)
        internal
        returns (uint80 remainQty)
    {
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].qty > qty) {
                continue;
            } else {
                // test
                console.log("close position qty: ", positions[i].qty);
                console.log("close position is long: ", positions[i].isLong);
                console.log("msg.sender........: ", msg.sender);
                hoax(address(test_wallet), 1000000000000000000000000000);
                console.log("msg.sender........2: ", msg.sender);
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

    function printArr(ITradingReader.Position[] memory positions) internal view {
        for (uint256 i = 0; i < positions.length; i++) {
            ITradingReader.Position memory position = positions[i];
            console.log("pair: ", position.pair);
            console.log("isLong: ", position.pair);
            console.log("entryPrice: ", position.entryPrice);
            console.log("qty: ", position.qty);
        }
    }
}
