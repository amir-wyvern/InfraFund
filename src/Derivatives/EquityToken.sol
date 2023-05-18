// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import {ERC4626} from "solmate/src/mixins/ERC4626.sol";
// import "solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IEquityToken.sol";

error WrongOwnerAddress();
error NotTheOwner();


contract EquityToken is ERC4626 {

    using SafeERC20 for IERC20;

    address private owner;
    ERC20 public token;

    constructor(
        IERC20 _token, 
        string memory _name, 
        string memory _symbol, 
        address _owner
        ) ERC20(_name, _symbol) ERC4626(_token) 
    {

        owner = _owner;
    }

    function mint(uint amount) external {

        if(msg.sender != owner)
            revert NotTheOwner();
        
        _mint(msg.sender, amount);
    }
}