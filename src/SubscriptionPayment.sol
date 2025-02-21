// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SubscriptionPayment is Ownable2Step {
    using SafeERC20 for IERC20;

    address immutable bnb;
    address immutable usdc;
    address immutable usdt;
    address immutable wbtc;
    
    // Address of the coldwallet
    address public coldWallet;

    // Custom errors
    error ColdWalletCannotBeZeroAddress();
    error InvalidToken();
    error InsufficientBalance();

    /// @notice This event is emitted when a payment is received for a subscription.
    /// @param _token Address of the token used for the payment. If the payment is made using native currency i.e. Ether 
    /// this will be the zero address (`address(0)`). For ERC-20 token payments, this will be the token address.
    /// @param _subscriber The address of the subscriber who made the payment.
    /// @param _amount The amount of the ETH/ERC-20 token paid by the subscriber. 
    event PaymentReceived(address indexed _token, address indexed _subscriber, uint256 indexed _amount); 
    
    /// @notice This event is emitted when the cold wallet address is updated.
    /// @param _coldWallet The new address of the cold wallet.
    event ColdWalletUpdated(address indexed _coldWallet);

    /// @notice This event is emitted when funds are withdrawn from the contract.
    /// @param _token Address of the token being withdrawn. If the address is `0`, it indicates the
    /// native currency i.e. Ether. Otherwise, it specifies the address of an ERC-20 token contract.
    /// @param _amount The amount of ETH/tokens withdrawn from the contract.
    event FundsWithdrawn(address indexed _token, uint256 indexed _amount);

    constructor(
        address _owner, 
        address _coldWallet, 
        address _bnb, 
        address _usdc, 
        address _usdt, 
        address _wbtc
    ) Ownable(_owner) {
        coldWallet = _coldWallet;
        bnb = _bnb;
        usdc = _usdc;
        usdt = _usdt;
        wbtc = _wbtc;
    }

    /// @notice Funtion to pay for subscription in BNB, USDC, USDT and WBTC.
    /// @param _amount The amount of tokens to deposit. It must be greater than zero.
    /// @param _token Address of the token the user wants to use to pay for the subscription.
    function payWithToken(uint256 _amount, address _token) external {
        require(_amount > 0, "Amount must be greater than zero");
        if(_token == bnb || _token == usdc || _token == usdt || _token == wbtc) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        } else {
            revert InvalidToken();
        }

        emit PaymentReceived(_token, msg.sender, _amount);
    }
    
    /// @notice Function to pay for subscription in ETH.
    function payWithETH() external payable {
        require(msg.value > 0, "Ether sent along should be greater than zero");

        emit PaymentReceived(address(0), msg.sender, msg.value);
    }

    /// @notice Function to update coldwallet.
    /// @param _coldWallet New address of the cold wallet, which should be a valid Ethereum address.
    function updateColdWallet(address _coldWallet) external onlyOwner {
        if(_coldWallet == address(0)) {
            revert ColdWalletCannotBeZeroAddress();
        }

        coldWallet = _coldWallet;

        emit ColdWalletUpdated(_coldWallet);
    }

    /// @notice Function to withdraw funds.
    /// @param _token The address of the token to withdraw. Use address(0) for Ether.
    /// Supported tokens: BNB, USDC, USDT and WBTC
    function withdraw(address _token) external onlyOwner {
        uint256 balance;
        if (_token == address(0)) {
            balance = address(this).balance;
            if(balance == 0) {
                revert InsufficientBalance();
            }
            
            (bool sent, ) = payable(coldWallet).call{value: balance}("");
            require(sent, "Failed to send Ether");
        } else {
            if(_token == bnb || _token == usdc || _token == usdt || _token == wbtc) {
                balance = IERC20(_token).balanceOf(address(this)); 
                if(balance == 0) {
                    revert InsufficientBalance();
                }

                IERC20(_token).safeTransferFrom(address(this), coldWallet, balance);
            } else {
                revert InvalidToken();
            }
        }

        emit FundsWithdrawn(_token, balance);
    }
}
