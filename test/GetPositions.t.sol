pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";



contract GetPositionsTest is Test {
    function testGetPositions() public view {
        ITradingReader.Position[] memory positions = ITradingReader(address(0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0))
            .getPositions(address(0x609F4479A03DF91C635C451835d22cC12C7108C0),address(0x0000000000000000000000000000000000000000));

        for (uint i = 0; i < positions.length; i++) {
            ITradingReader.Position memory position = positions[i];
            console.log("pair: ",position.pair);
            console.log("isLong: ",position.pair);
            console.log("entryPrice: ",position.entryPrice);
            console.log("qty: ",position.qty);
        }
    }
}
