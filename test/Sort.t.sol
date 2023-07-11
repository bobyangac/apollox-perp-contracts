pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";

// contract SortPositionTest is Test {
//     struct Position {
//         uint64 idx;
//         uint64 entryPrice;
//     }

//     Position[] public positions;

//     function testClosePositions() public {
//         positions.push(Position(0, 100));
//         positions.push(Position(1, 10));
//         positions.push(Position(2, 50));
//         positions.push(Position(3, 20));

//         sortPositionsByEntryPrice(positions);
//     }

//     function sortPositionsByEntryPrice(Position[] calldata positions) internal {
//         uint256 n = positions.length;
//         for (uint256 i = 0; i < n - 1; i++) {
//             for (uint256 j = 0; j < n - i - 1; j++) {
//                 if (positions[j].entryPrice > positions[j + 1].entryPrice) {
//                     Position memory temp = positions[j];
//                     positions[j] = positions[j + 1];
//                     positions[j + 1] = temp;
//                 }
//             }
//         }
//     }
// }

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";

contract SortPositionTest is Test {
    struct Position {
        uint64 idx;
        uint64 entryPrice;
    }

    Position[] public positions;

    function testClosePositions() public {
        positions.push(Position(0, 100));
        positions.push(Position(1, 10));
        positions.push(Position(2, 50));
        positions.push(Position(3, 20));

        printArr();

        sortPositionsByEntryPriceAscend();

        printArr();

        sortPositionsByEntryPriceDescend();

        printArr();
    }

    function sortPositionsByEntryPriceAscend() internal {
        uint256 n = positions.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (positions[j].entryPrice > positions[j + 1].entryPrice) {
                    Position memory temp = positions[j];
                    positions[j] = positions[j + 1];
                    positions[j + 1] = temp;
                }
            }
        }
    }

    function sortPositionsByEntryPriceDescend() internal {
        uint256 n = positions.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (positions[j].entryPrice < positions[j + 1].entryPrice) {
                    Position memory temp = positions[j];
                    positions[j] = positions[j + 1];
                    positions[j + 1] = temp;
                }
            }
        }
    }

    function printArr() internal view {
        uint256 n = positions.length;
        for (uint256 i = 0; i < n ; i++) {
            console.log("idx: ", positions[i].idx);
            console.log("entryPrice: ", positions[i].entryPrice);
        }
    }
}