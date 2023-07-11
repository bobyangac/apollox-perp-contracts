pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/ApolloxTrade.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConsoleTest is Test {
    address usdt_address = 0x55d398326f99059fF775485246999027B3197955;

    function testLogSomething() public {
        console.log("Log something here", 123);

        int256 x = -1;
        console.logInt(x);

        uint256 balBefore = IERC20(address(usdt_address)).balanceOf(address(this));
        console.log("balance before", balBefore / 1e18);
    }
}
