pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/IPriceFacade.sol";

contract GetPriceTest is Test {
    function testGetOraclePrice() public view {
        (uint64 price, uint40 updatedAt) = IPriceFacade(address(0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0))
            .getPriceFromCacheOrOracle(address(0x2170Ed0880ac9A755fd29B2688956BD959F933F8));

        console.log("price", price);
        console.log("updatedAt", updatedAt);
    }
}
