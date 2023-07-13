pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/ApolloxTrade.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "../contracts/diamond/interfaces/IPriceFacade.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";
import "../contracts/diamond/libraries/LibTrading.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PlaceMarketCallTest is Test {
    address eth_usd_address = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address usdt_address = 0x55d398326f99059fF775485246999027B3197955;
    address test_wallet = 0x609F4479A03DF91C635C451835d22cC12C7108C0;
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;

    event MarketPendingTradeOut(address indexed user, bytes32 indexed tradeHash, IBook.OpenDataInput trade);

    ApolloxTrade apolloxTrade = new ApolloxTrade();

    function testPlaceMarket() public {
        // test open market order input
        IBook.OpenDataInput memory openDataInput = IBook.OpenDataInput({
            pairBase: address(eth_usd_address),
            isLong: true,
            tokenIn: usdt_address,
            amountIn: 70000000000000000000,
            qty: 1500000000,
            price: 197506058732,
            stopLoss: 149924846985,
            takeProfit: 327960602781,
            broker: 1
        });

        deal(usdt_address,test_wallet,1e6 * 1e18, true);
        hoax(test_wallet);
        bool success = IERC20(usdt_address).approve(address(apolloxTrade),1e6 * 1e18);
        console.log("success", success);
        console.log("success", address(apolloxTrade));
        uint256 allowance = IERC20(usdt_address).allowance(test_wallet,address(apolloxTrade));
        console.log("allowance", allowance / 1e18);

        hoax(address(apolloxTrade));
        bool successContract = IERC20(usdt_address).approve(contract_address,1e6 * 1e18);
        console.log("successContract", successContract);

        uint256 balBefore = IERC20(usdt_address).balanceOf(address(this));
        console.log("balance before", balBefore / 1e18);
        deal(usdt_address,address(this),1e6 * 1e18, true);
        uint256 balAfter = IERC20(usdt_address).balanceOf(address(this));
        console.log("balance after", balAfter / 1e18);

        apolloxTrade.openMarketTradeWithPositionCleaning(test_wallet,openDataInput);

        ITrading.PendingTrade memory pt = ITrading.PendingTrade(
            address(apolloxTrade), openDataInput.broker, openDataInput.isLong, openDataInput.price, openDataInput.pairBase, openDataInput.amountIn,
            openDataInput.tokenIn, openDataInput.qty, openDataInput.stopLoss, openDataInput.takeProfit, uint128(block.number)
        );
        
        LibTrading.TradingStorage storage ts = LibTrading.tradingStorage();
        bytes32 tradeHash = keccak256(abi.encode(pt, ts.salt, "trade", block.number, block.timestamp));

        emit MarketPendingTradeOut(address(apolloxTrade), tradeHash, openDataInput); 
    }
}