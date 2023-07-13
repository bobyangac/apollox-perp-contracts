// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IBook.sol";
import "./ITrading.sol";

interface ITradingPortal is ITrading, IBook {

    event FundingFeeAddLiquidity(address indexed token, uint256 amount);
    event MarketPendingTrade(address indexed user, bytes32 indexed tradeHash, OpenDataInput trade);
    event UpdateTradeTp(address indexed user, bytes32 indexed tradeHash, uint256 oldTp, uint256 tp);
    event UpdateTradeSl(address indexed user, bytes32 indexed tradeHash, uint256 oldSl, uint256 sl);
    event UpdateMargin(address indexed user, bytes32 indexed tradeHash, uint256 beforeMargin, uint256 margin);

    function openMarketTrade(OpenDataInput calldata openData) external;

    function updateTradeTp(bytes32 tradeHash, uint64 takeProfit) external;

    function updateTradeSl(bytes32 tradeHash, uint64 stopLoss) external;

    // stopLoss is allowed to be equal to 0, which means the sl setting is removed.
    // takeProfit must be greater than 0
    function updateTradeTpAndSl(bytes32 tradeHash, uint64 takeProfit, uint64 stopLoss) external;

    function settleLpFundingFee(uint256 lpReceiveFundingFeeUsd) external;

    function closeTrade(bytes32 tradeHash) external;
    
    function addMargin(bytes32 tradeHash, uint96 amount) external;
}


// MarketPendingTradeOut(user: ApolloxTrade: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f], tradeHash: 0x78bc38f8dd965f15d84f1c7449253f467d9203e8f6f5b73f0673cf1f9ab8b822, trade: (0x2170Ed0880ac9A755fd29B2688956BD959F933F8, true, 0x55d398326f99059fF775485246999027B3197955, 70000000000000000000 [7e19], 1500000000 [1.5e9], 197506058732 [1.975e11], 149924846985 [1.499e11], 327960602781 [3.279e11], 1))
// MarketPendingTrade(user: ApolloxTrade: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f], tradeHash: 0xd35599655700c22b4bb473e3ac5de26f34caab4341beb0cbbeb411a9d3e8cbc3, trade: (0x2170Ed0880ac9A755fd29B2688956BD959F933F8, true, 0x55d398326f99059fF775485246999027B3197955, 70000000000000000000 [7e19], 1500000000 [1.5e9], 197506058732 [1.975e11], 149924846985 [1.499e11], 327960602781 [3.279e11], 1))