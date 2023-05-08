// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./ICharityToken.sol";

errpr AmountIsZero();

contract CharityToken is ICharityToken, ERC20, Initializable {

    address private owner;
    IERC20 paymentToken;

    mapping(address => uint) private donators;

    event Donated(address indexed user, uint256 indexed amount);

    function initialize(
        IERC20 _paymentToken,
        address _owner,
        string calldata __name,
        string calldata __symbol
    )
        external
        initializer
    {
        owner = _owner;
        paymentToken = _paymentToken;
        _name = __name;
        _symbol = __symbol;
    }

    function donate(uint amount) external {

        if (amount == 0)
            revert AmountIsZero();

        donators[msg.sender] == amount;
        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Donated(msg.sender, amount);
    }
}