pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/ApolloxTrade.sol";
import "../contracts/diamond/interfaces/IBook.sol";


contract AddMarginTest is Test {
    address eth_usd_address = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address usdt_address = 0x55d398326f99059fF775485246999027B3197955;
    address test_wallet = 0x609F4479A03DF91C635C451835d22cC12C7108C0;
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;

    function testAddMargin() public {
        startHoax(test_wallet);

        ITradingReader.Position[] memory positions = ITradingReader(contract_address)
            .getPositions(test_wallet,address(0x0000000000000000000000000000000000000000));

        for (uint i = 0; i < positions.length; i++) {
            ITradingReader.Position memory position = positions[i];
            console.log("pair: ",position.pair);
            console.log("isLong: ",position.pair);
            console.log("entryPrice: ",position.entryPrice);
            console.log("qty: ",position.qty);
            bool approveSuccess = IERC20(usdt_address).approve(contract_address,10000000000000000000);
            console.log("approveSuccess: ",approveSuccess);
            ITradingPortal(contract_address).addMargin(positions[i].positionHash,10000000000000000000);
        }
    }
}