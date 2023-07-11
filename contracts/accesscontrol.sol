pragma solidity ^0.8.18;

contract Ownable {
    address payable public _OWNER_;
    address payable public _NEW_OWNER_;

    // ============ Events ============

    event OwnershipTransferPrepared(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == _OWNER_, "NOT_OWNER");
        _;
    }

    // ============ Functions ============

    constructor() {
        _OWNER_ = payable(msg.sender);
        emit OwnershipTransferred(address(0), _OWNER_);
    }

    function transferOwnership(address payable newOwner) external onlyOwner {
        require(newOwner != address(0), "INVALID_OWNER");
        emit OwnershipTransferPrepared(_OWNER_, newOwner);
        _NEW_OWNER_ = newOwner;
    }

    function claimOwnership() external {
        require(msg.sender == _NEW_OWNER_, "INVALID_CLAIM");
        emit OwnershipTransferred(_OWNER_, _NEW_OWNER_);
        _OWNER_ = _NEW_OWNER_;
        _NEW_OWNER_ = payable(address(0));
    }
}

contract Tradable is Ownable {
    mapping(address => bool) _ALLOWEDTRADERS_;

    modifier onlyTraders() {
        require(_ALLOWEDTRADERS_[msg.sender], "NOT_TRADER");
        _;
    }

    function approveTraderAddress(address trader) external onlyOwner {
        _ALLOWEDTRADERS_[trader] = true;
    }

    function removeTraderAddress(address trader) external onlyOwner {
        require(_ALLOWEDTRADERS_[trader], "TRADER_NOT_IN_LIST");
        _ALLOWEDTRADERS_[trader] = false;
    }
}