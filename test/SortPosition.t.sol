pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";

contract SortPositionsTest is Test {
    address test_wallet = 0x609F4479A03DF91C635C451835d22cC12C7108C0;
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;

    function testSortPositions() public {
        ITradingReader.Position[] memory positions = ITradingReader(address(contract_address)).getPositions(
            address(test_wallet), address(0x0000000000000000000000000000000000000000)
        );

        hoax(address(test_wallet), 1000000000);

        ITradingReader.Position[] memory longPositions;
        ITradingReader.Position[] memory shortPositions;

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isLong) {
                longPositions = appendPosition(longPositions, positions[i]);
            } else {
                shortPositions = appendPosition(shortPositions, positions[i]);
            }
        }

        console.log("--------long---------");
        longPositions = sortPositionsByEntryPriceAscend(longPositions);
        printArr(longPositions);
        console.log("--------short---------");
        shortPositions = sortPositionsByEntryPriceDescend(shortPositions);
        printArr(shortPositions);
    }

    function appendPosition(ITradingReader.Position[] memory arr, ITradingReader.Position memory pos) internal pure returns (ITradingReader.Position[] memory) {
        ITradingReader.Position[] memory newArr = new ITradingReader.Position[](arr.length + 1);
        for (uint256 i = 0; i < arr.length; i++) {
            newArr[i] = arr[i];
        }
        newArr[arr.length] = pos;
        return newArr;
    }

    function sortPositionsByEntryPriceAscend(ITradingReader.Position[] memory positions) internal pure returns (ITradingReader.Position[] memory) {
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

    function sortPositionsByEntryPriceDescend(ITradingReader.Position[] memory positions) internal pure returns (ITradingReader.Position[] memory) {
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
