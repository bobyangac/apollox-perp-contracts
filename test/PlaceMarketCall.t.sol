pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/ApolloxTrade.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract PlaceMarketCallTest is Test {
    address eth_usd_address = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address usdt_address = 0x55d398326f99059fF775485246999027B3197955;
    address test_wallet = 0x609F4479A03DF91C635C451835d22cC12C7108C0;

    // ApolloxTrade apolloxTrade = new ApolloxTrade();

    function testPlaceMarket() public {
        // // test open market order input
        // IBook.OpenDataInput memory openDataInput = IBook.OpenDataInput({
        //     pairBase: address(eth_usd_address),
        //     isLong: true,
        //     tokenIn: address(usdt_address),
        //     amountIn: 70000000000000000000,
        //     qty: 1500000000,
        //     price: 186006058732,
        //     stopLoss: 149924846985,
        //     takeProfit: 327960602781,
        //     broker: 1
        // });

        uint256 balBefore = IERC20(address(usdt_address)).balanceOf(address(this));
        console.log("balance before", balBefore / 1e18);
        deal(address(usdt_address),address(this),1e6 * 1e18, true);
        uint256 balAfter = IERC20(address(usdt_address)).balanceOf(address(this));
        console.log("balance after", balAfter / 1e18);

        // apolloxTrade.openMarketTradeWithPositionCleaning(address(1),openDataInput);
    }

    // openMarketTradeWithPositionCleaning(openDataInput);
}