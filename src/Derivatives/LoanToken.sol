// // SPDX-License-Identifier: BSD-3-Clause license
// pragma solidity 0.8.17;

// contract LoanToken is ILoanToken, ERC20 {
//     using SafeMath for uint256;

//     address public override borrower;
//     uint256 public override amount;
//     uint256 public override term;
//     uint256 public override apy;

//     uint256 public override start;
//     address public override lender;
//     uint256 public override debt;

//     uint256 public redeemed;

//     // borrow fee -> 100 = 1%
//     uint256 public override borrowerFee = 25;

//     // whitelist for transfers
//     mapping(address => bool) public canTransfer;

//     Status public override status;

//     IERC20 public currencyToken;

//     /**
//      * @dev Emitted when the loan is funded
//      * @param lender Address which funded the loan
//      */
//     event Funded(address lender);

//     /**
//      * @dev Emitted when transfer whitelist is updated
//      * @param account Account to whitelist for transfers
//      * @param status New whitelist status
//      */
//     event TransferAllowanceChanged(address account, bool status);

//     /**
//      * @dev Emitted when borrower withdraws funds
//      * @param beneficiary Account which will receive funds
//      */
//     event Withdrawn(address beneficiary);

//     /**
//      * @dev Emitted when term is over
//      * @param status Final loan status
//      * @param returnedAmount Amount that was retured before expiry
//      */
//     event Closed(Status status, uint256 returnedAmount);

//     /**
//      * @dev Emitted when a LoanToken is redeemed for underlying currencyTokens
//      * @param receiver Receiver of currencyTokens
//      * @param burnedAmount Amount of LoanTokens burned
//      * @param redeemedAmound Amount of currencyToken received
//      */
//     event Redeemed(address receiver, uint256 burnedAmount, uint256 redeemedAmound);

//     /**
//      * @dev Create a Loan
//      * @param _currencyToken Token to lend
//      * @param _borrower Borrwer addresss
//      * @param _amount Borrow amount of currency tokens
//      * @param _term Loan length
//      * @param _apy Loan APY
//      */
//     constructor(
//         IERC20 _currencyToken,
//         address _borrower,
//         uint256 _amount,
//         uint256 _term,
//         uint256 _apy
//     ) public ERC20("Loan Token", "LOAN") {
//         currencyToken = _currencyToken;
//         borrower = _borrower;
//         amount = _amount;
//         term = _term;
//         apy = _apy;
//         debt = interest(amount);
//     }

//     /**
//      * @dev Only borrwer can withdraw & repay loan
//      */
//     modifier onlyBorrower() {
//         require(msg.sender == borrower, "LoanToken: Caller is not the borrower");
//         _;
//     }

//     /**
//      * @dev Only when loan is Settled
//      */
//     modifier onlyClosed() {
//         require(status == Status.Settled || status == Status.Defaulted, "LoanToken: Current status should be Settled or Defaulted");
//         _;
//     }

//     /**
//      * @dev Only when loan is Funded
//      */
//     modifier onlyOngoing() {
//         require(status == Status.Funded || status == Status.Withdrawn, "LoanToken: Current status should be Funded or Withdrawn");
//         _;
//     }

//     /**
//      * @dev Only when loan is Funded
//      */
//     modifier onlyFunded() {
//         require(status == Status.Funded, "LoanToken: Current status should be Funded");
//         _;
//     }

//     /**
//      * @dev Only when loan is Withdrawn
//      */
//     modifier onlyAfterWithdraw() {
//         require(status >= Status.Withdrawn, "LoanToken: Only after loan has been withdrawn");
//         _;
//     }

//     /**
//      * @dev Only when loan is Awaiting
//      */
//     modifier onlyAwaiting() {
//         require(status == Status.Awaiting, "LoanToken: Current status should be Awaiting");
//         _;
//     }

//     /**
//      * @dev Only whitelisted accounts or lender
//      */
//     modifier onlyWhoCanTransfer(address sender) {
//         require(
//             sender == lender || canTransfer[sender],
//             "LoanToken: This can be performed only by lender or accounts allowed to transfer"
//         );
//         _;
//     }

//     /**
//      * @dev Only lender can perform certain actions
//      */
//     modifier onlyLender() {
//         require(msg.sender == lender, "LoanToken: This can be performed only by lender");
//         _;
//     }

//     /**
//      * @dev Return true if this contract is a LoanToken
//      * @return True if this contract is a LoanToken
//      */
//     function isLoanToken() external override pure returns (bool) {
//         return true;
//     }

//     /**
//      * @dev Get loan parameters
//      * @return amount, term, apy
//      */
//     function getParameters()
//         external
//         override
//         view
//         returns (
//             uint256,
//             uint256,
//             uint256
//         )
//     {
//         return (amount, apy, term);
//     }

//     /**
//      * @dev Get coupon value of this loan token in currencyToken
//      * This assumes the loan will be paid back on time, with interest
//      * @param _balance number of LoanTokens to get value for
//      * @return coupon value of _balance LoanTokens in currencyTokens
//      */
//     function value(uint256 _balance) external override view returns (uint256) {
//         if (_balance == 0) {
//             return 0;
//         }

//         uint256 passed = block.timestamp.sub(start);
//         if (passed > term) {
//             passed = term;
//         }

//         uint256 helper = amount.mul(apy).mul(passed).mul(_balance);
//         // assume month is 30 days
//         uint256 interest = helper.div(360 days).div(10000).div(totalSupply());

//         return amount.add(interest);
//     }

//     /**
//      * @dev Fund a loan
//      * Set status, start time, lender
//      */
//     function fund() external override onlyAwaiting {
//         status = Status.Funded;
//         start = block.timestamp;
//         lender = msg.sender;
//         _mint(msg.sender, debt);
//         require(currencyToken.transferFrom(msg.sender, address(this), receivedAmount()));

//         emit Funded(msg.sender);
//     }

//     /**
//      * @dev Whitelist accounts to transfer
//      * @param account address to allow transfers for
//      * @param _status true allows transfers, false disables transfers
//      */
//     function allowTransfer(address account, bool _status) external override onlyLender {
//         canTransfer[account] = _status;
//         emit TransferAllowanceChanged(account, _status);
//     }

//     /**
//      * @dev Borrower calls this function to withdraw funds
//      * Sets the status of the loan to Withdrawn
//      * @param _beneficiary address to send funds to
//      */
//     function withdraw(address _beneficiary) external override onlyBorrower onlyFunded {
//         status = Status.Withdrawn;
//         require(currencyToken.transfer(_beneficiary, receivedAmount()));

//         emit Withdrawn(_beneficiary);
//     }

//     /**
//      * @dev Close the loan and check if it has been repaid
//      */
//     function close() external override onlyOngoing {
//         require(start.add(term) <= block.timestamp, "LoanToken: Loan cannot be closed yet");
//         if (_balance() >= debt) {
//             status = Status.Settled;
//         } else {
//             status = Status.Defaulted;
//         }

//         emit Closed(status, _balance());
//     }

//     /**
//      * @dev Redeem LoanToken balances for underlying currencyToken
//      * Can only call this function after the loan is Closed
//      * @param _amount amount to redeem
//      */
//     function redeem(uint256 _amount) external override onlyClosed {
//         uint256 amountToReturn = _amount.mul(_balance()).div(totalSupply());
//         redeemed = redeemed.add(amountToReturn);
//         _burn(msg.sender, _amount);
//         require(currencyToken.transfer(msg.sender, amountToReturn));

//         emit Redeemed(msg.sender, _amount, amountToReturn);
//     }

//     /**
//      * @dev Function for borrower to repay the loan
//      * Borrower can repay at any time
//      * @param _sender account sending currencyToken to repay
//      * @param _amount amount of currencyToken to repay
//      */
//     function repay(address _sender, uint256 _amount) external override onlyAfterWithdraw {
//         require(currencyToken.transferFrom(_sender, address(this), _amount));
//     }

//     /**
//      * @dev Check if loan has been repaid
//      * @return Boolean representing whether the loan has been repaid or not
//      */
//     function repaid() external override view onlyAfterWithdraw returns (uint256) {
//         return _balance().add(redeemed);
//     }

//     /**
//      * @dev Public currency token balance function
//      * @return currencyToken balance of this contract
//      */
//     function balance() external override view returns (uint256) {
//         return _balance();
//     }

//     /**
//      * @dev Get currency token balance for this contract
//      * @return currencyToken balance of this contract
//      */
//     function _balance() internal view returns (uint256) {
//         return currencyToken.balanceOf(address(this));
//     }

//     /**
//      * @dev Calculate amount borrowed minus fee
//      * @return Amount minus fees
//      */
//     function receivedAmount() public override view returns (uint256) {
//         return amount.sub(amount.mul(borrowerFee).div(10000));
//     }

//     /**
//      * @dev Calculate interest that will be paid by this loan for an amount
//      * (amount * apy * term) / (360 days / precision)
//      * @param _amount amount
//      * @return uint256 Amount of interest paid for _amount
//      */
//     function interest(uint256 _amount) internal view returns (uint256) {
//         return _amount.add(_amount.mul(apy).mul(term).div(360 days).div(10000));
//     }

//     /**
//      * @dev get profit for this loan
//      * @return profit for this loan
//      */
//     function profit() external override view returns (uint256) {
//         return debt.sub(amount);
//     }

//     /**
//      * @dev Override ERC20 _transfer so only whitelisted addresses can transfer
//      * @param sender sender of the transaction
//      * @param recipient recipient of the transaction
//      * @param _amount amount to send
//      */
//     function _transfer(
//         address sender,
//         address recipient,
//         uint256 _amount
//     ) internal override onlyWhoCanTransfer(sender) {
//         return super._transfer(sender, recipient, _amount);
//     }
// }