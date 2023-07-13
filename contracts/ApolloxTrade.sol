pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../contracts/diamond/interfaces/ITradingReader.sol";
import "../contracts/diamond/interfaces/ITradingPortal.sol";
import "../contracts/diamond/interfaces/IBook.sol";
import "../contracts/diamond/interfaces/ITradingConfig.sol";
import "../contracts/accesscontrol.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract ApolloxTrade is Tradable {
    address contract_address = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;
    address usdt_address     = 0x55d398326f99059fF775485246999027B3197955;

    event Result(address indexed sender, uint80 indexed inputQty, uint80 indexed remainQty);

    function openMarketTradeWithPositionCleaning(address vault, ITradingPortal.OpenDataInput calldata openDataInput) external {
        uint80 originQty = openDataInput.qty;

        ITradingReader.Position[] memory positions = ITradingReader(contract_address).getPositions(
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
            ITradingConfig.TradingConfig memory tc = ITradingConfig(contract_address).getTradingConfig();

            uint256 notionalUsd = openDataInput.price * openDataInput.qty;

            // 5% buffer for min notional
            if (notionalUsd < (tc.minNotionalUsd * 105) / 100) {
                emit Result(msg.sender, originQty, remainQty);
            } else {
                uint96 amountIn = remainQty/originQty * openDataInput.amountIn;

                IBook.OpenDataInput memory openDataInputNew = IBook.OpenDataInput({
                    pairBase: openDataInput.pairBase,
                    isLong: openDataInput.isLong,
                    tokenIn: openDataInput.tokenIn,
                    amountIn: amountIn,
                    qty: remainQty,
                    price: openDataInput.price,
                    stopLoss: openDataInput.stopLoss,
                    takeProfit: openDataInput.takeProfit,
                    broker: openDataInput.broker
                });

                safeTransferFromVault(vault, amountIn);
                bool approveSuccess = IERC20(usdt_address).approve(contract_address,amountIn);
                require(approveSuccess, "approve usdt to apollox failed");
                
            
                ITradingPortal(contract_address).openMarketTrade(openDataInputNew);
                emit Result(msg.sender, originQty, 0);

                returnRemainingToVault(vault);
            }
        }
    }

    function closePosition(address vault, bytes32 tradeHash) external {
        ITradingPortal(contract_address).closeTrade(tradeHash);
        returnRemainingToVault(vault);
    }

    function addMargin(address vault, bytes32 tradeHash, uint96 amount) external {
        safeTransferFromVault(vault, amount);
        bool approveSuccess = IERC20(usdt_address).approve(contract_address, amount);
        require(approveSuccess, "approve usdt to apollox failed");

        ITradingPortal(contract_address).addMargin(tradeHash, amount);
        returnRemainingToVault(vault);
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
                ITradingPortal(contract_address).closeTrade(positions[i].positionHash);
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
        if (n==0) {
            return positions;
        }
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
        if (n==0) {
            return positions;
        }
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

    function safeTransferFromVault(address vault, uint256 amount) internal {
        require(IERC20(usdt_address).allowance(vault, address(this)) >= amount,"vault not allowed.");
        SafeERC20.safeTransferFrom(IERC20(usdt_address), address(vault), address(this), amount);
    }

    function returnRemainingToVault(address vault) internal {
        uint256 usdtBalance = IERC20(usdt_address).balanceOf(address(this));
        if (usdtBalance > 0) {
            SafeERC20.safeTransfer(IERC20(usdt_address), address(vault), usdtBalance);
        }
    }
}
