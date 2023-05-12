// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IEquityToken.sol";

error WrongOwnerAddress();
error NotTheOwner();

contract EquityToken is IEquityToken, ERC4626 {

    using SafeERC20 for IERC20;

    address private owner;
    string private _name;
    string private _symbol;
    IERC20 private paymentToken;

    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);

    modifier onlyOwner() {

        if(msg.sender != owner)
            revert NotTheOwner();
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address _owner,
        IERC20 _token
    ) ERC4626(_token) {

        if(_owner == address(0))
            revert WrongOwnerAddress();

        owner = _owner;
        paymentToken = _token;
    }

}