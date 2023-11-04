// // SPDX-License-Identifier: BSD-3-Clause license
// pragma solidity 0.8.17;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "./ICharityToken.sol";

// error AmountIsZero();
// error WrongOwnerAddress();
// error PreviousToken();

// contract CharityToken is ICharityToken, ERC20, Initializable {

//     using SafeERC20 for IERC20;
//     address private owner;
//     string private _name;
//     string private _symbol;
//     IERC20 private paymentToken;

//     mapping(address => uint) private donators;

//     event Donated(address indexed user, uint256 indexed amount);

//     constructor(
//         string memory name_,
//         string memory symbol_,
//         address _owner,
//         IERC20 _token
//     ) ERC20(name_, symbol_) {

//         if(_owner == address(0))
//             revert WrongOwnerAddress();

//         owner = _owner;
//         paymentToken = _token;
//     }

//     function donate(uint amount) external {

//         if (amount == 0)
//             revert AmountIsZero();

//         donators[msg.sender] += amount;
//         paymentToken.safeTransferFrom(msg.sender, address(this), amount);
//         emit Donated(msg.sender, amount);
//     }

//     function changeToken(IERC20 _token) external onlyOwner {

//         if(_token == paymentToken)
//             revert PreviousToken();
            
//         paymentToken = _token;
//     }
// }