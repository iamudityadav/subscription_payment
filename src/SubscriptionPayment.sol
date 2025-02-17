// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/foundry-chainlink-toolkit/lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SubscriptionPayment is Ownable2Step {
    using SafeERC20 for IERC20;

    address immutable bnb;
    address immutable usdc;
    address immutable usdt;
    address immutable wbtc;

    AggregatorV3Interface immutable priceFeedBNBUSD;
    AggregatorV3Interface immutable priceFeedETHUSD;
    AggregatorV3Interface immutable priceFeedWBTCUSD;
 
    // Subscription fee in USD
    uint256 public subscriptionFeeUSD;

    // Subscription time period in days
    uint256 public subscriptionPeriod;
    
    // Address of coldwallet
    address public coldWallet;

    // Mapping to store subscription info of user
    mapping(address => Subscription) private userSubscription;

    struct Subscription{
        uint256 subscriptionStartsAt;
        uint256 subscriptionEndsAt;
    }

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
    
    /// @notice This event is emitted when the subscription fee in USD is updated.
    /// @param _subscriptionFeeUSD The new subscription fee in USD.
    event SubscriptionFeeUSDUpdated(uint256 indexed _subscriptionFeeUSD);

    /// @notice This event is emitted when the subscription period is updated.
    /// @param _subscriptionPeriod The new subscription period in days.
    event SubscriptionPeriodUpdated(uint256 indexed _subscriptionPeriod);
    
    /// @notice This event is emitted when the cold wallet address is updated.
    /// @param _coldWallet The new address of the cold wallet.
    event ColdWalletUpdated(address indexed _coldWallet);

    /// @notice This event is emitted when funds are withdrawn from the contract.
    /// @param _token Address of the token being withdrawn. If the address is `0`, it indicates the
    /// native currency i.e. Ether. Otherwise, it specifies the address of an ERC-20 token contract.
    /// @param _amount The amount of ETH/tokens withdrawn from the contract.
    event FundsWithdrawn(address indexed _token, uint256 indexed _amount);

    constructor(
        uint256 _subscriptionFeeUSD,
        uint256 _subscriptionPeriod,
        address _owner, 
        address _coldWallet, 
        address _bnb, 
        address _usdc, 
        address _usdt, 
        address _wbtc,
        address _priceFeedBNBUSD,
        address _priceFeedETHUSD,
        address _priceFeedWBTCUSD
    ) Ownable(_owner) {
        subscriptionFeeUSD = _subscriptionFeeUSD;
        subscriptionPeriod = _subscriptionPeriod;
        coldWallet = _coldWallet;
        bnb = _bnb;
        usdc = _usdc;
        usdt = _usdt;
        wbtc = _wbtc;

        priceFeedBNBUSD = AggregatorV3Interface(_priceFeedBNBUSD);
        priceFeedETHUSD = AggregatorV3Interface(_priceFeedETHUSD);
        priceFeedWBTCUSD = AggregatorV3Interface(_priceFeedWBTCUSD);
    }

    /// @notice Function to fetch subscription fee.
    /// @param _token Address of the token for subscription fee is to be fetched.
    /// @return Subscription fee in '_token'.
    function getSubscriptionFee(address _token) public view returns (uint256){
        uint256 subsFee;
        if(_token == wbtc) {
            (, int256 price, , , ) = priceFeedWBTCUSD.latestRoundData();
            require(price > 0, "Invalid price data");

            subsFee = (subscriptionFeeUSD * 10**16) / uint256(price);
        } else {
            int256 price;
            if(_token == bnb) {
                (, price, , , ) = priceFeedBNBUSD.latestRoundData();
                require(price > 0, "Invalid price data");
            } else {
                (, price, , , ) = priceFeedETHUSD.latestRoundData();
                require(price > 0, "Invalid price data");
            }

            uint256 adjustedPrice = uint256(price) * 10**10;
            subsFee = (subscriptionFeeUSD * 10**36) / adjustedPrice;
        }

        return subsFee;
    }

    /// @notice Funtion to pay for subscription in BNB, USDC, USDT and WBTC.
    /// @param _token Address of the token the user wants to use to pay for the subscription.
    function startSubscriptionWithToken(address _token) external {
        uint256 amount;
        if(_token == bnb) {
            amount = getSubscriptionFee(bnb);
            IERC20(bnb).safeTransferFrom(msg.sender, address(this), amount);
        } else if(_token == usdc) {
            amount = subscriptionFeeUSD * 10 ** 6;
            IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
        } else if(_token == usdt) {
            amount = subscriptionFeeUSD * 10 ** 6;
            IERC20(usdt).safeTransferFrom(msg.sender, address(this), amount); 
        } else if(_token == wbtc) {
            amount = getSubscriptionFee(wbtc);
            IERC20(wbtc).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            revert InvalidToken();
        }

        setSubscription(msg.sender);

        emit PaymentReceived(_token, msg.sender, amount);
    }
    
    /// @notice Function to pay for subscription in ETH.
    /// @dev The function checks that the amount of ETH sent is within a 2% slippage tolerance of the subscription fee.
    /// If the ETH sent is outside this range, the transaction will revert
    function startSubscriptionWithETH() external payable {
        // 2% slippage
        require(msg.value > (getSubscriptionFee(address(0))*92)/100 && msg.value < (getSubscriptionFee(address(0))*102)/100, "Ether sent along should be equal to subscription fee");
        setSubscription(msg.sender);

        emit PaymentReceived(address(0), msg.sender, msg.value);
    }

    /// @notice Function to update the subscription of a specific user.
    /// @param _user Address of the user for whom the subscription is being updated. 
    function setSubscription(address _user) private {
        if(userSubscription[_user].subscriptionStartsAt != 0) {
            userSubscription[_user].subscriptionEndsAt = userSubscription[_user].subscriptionEndsAt + (subscriptionPeriod * 1 days);

        } else {
            userSubscription[_user].subscriptionStartsAt = block.timestamp;
            userSubscription[_user].subscriptionEndsAt = block.timestamp + (subscriptionPeriod * 1 days);
        }
    }

    /// @notice Function to check if a user has valid subscription.
    /// @param _user Address of the user whose subscription status is being checked.
    /// @return bool Boolean value indicating the user's subscription status.
    function isSubscribed(address _user) public view returns (bool){
        return block.timestamp < userSubscription[_user].subscriptionEndsAt; 
    }

    /// @notice Function to fetch subscription details of a user.
    /// @param _user Address of the user whose subscription details is being fetched.
    /// @return Subscription Returns a `Subscription` struct containing the user's subscription details.
    function getSubscriptionData(address _user) external view returns (Subscription memory) {
        Subscription memory subscription = Subscription(
            userSubscription[_user].subscriptionStartsAt,
            userSubscription[_user].subscriptionEndsAt
        );

        return subscription;
    }

    /// @notice Function to update subscription fee.
    /// @param _subscriptionFeeUSD The new subscription fee in USD.
    function updateSubscriptionFeeUSD(uint256 _subscriptionFeeUSD) external onlyOwner{
        subscriptionFeeUSD = _subscriptionFeeUSD;

        emit SubscriptionFeeUSDUpdated(_subscriptionFeeUSD);
    }

    /// @notice Function to update subscription time period.
    /// @param _subscriptionPeriod The new subscription period in days.
    function updateSubscriptionPeriod(uint256 _subscriptionPeriod) external onlyOwner{
        subscriptionPeriod = _subscriptionPeriod;
        
       emit SubscriptionPeriodUpdated(_subscriptionPeriod);
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
    /// @param _token The address of the token to be withdrawn.
    /// If the address is `0`, it indicates the native currency i.e. Ether. 
    /// Otherwise, it specifies the address of an ERC-20 token contract.
    function withdraw(address _token) external onlyOwner {
        uint256 balance;
        if (_token == address(0)) {
            balance = address(this).balance;
            if(balance == 0) {
                revert InsufficientBalance();
            }
            
            payable(coldWallet).transfer(balance);
        } else {
            balance = IERC20(_token).balanceOf(address(this)); 
            if(balance == 0) {
                revert InsufficientBalance();
            }

            IERC20(_token).safeTransferFrom(address(this), coldWallet, balance);
        }

        emit FundsWithdrawn(_token, balance);
    }
}
