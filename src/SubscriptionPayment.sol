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

    AggregatorV3Interface internal priceFeedBNBUSD;
    AggregatorV3Interface internal priceFeedETHUSD;
    AggregatorV3Interface internal priceFeedWBTCUSD;

    uint256 public subscriptionFeeUSD;
    uint256 public subscriptionPeriod;

    uint256 public balanceBNB;
    uint256 public balanceETH;
    uint256 public balanceUSDC;
    uint256 public balanceUSDT;
    uint256 public balanceWBTC;
    address public coldWallet;

    mapping(address => Subscription) private userToSubscription;

    struct Subscription{
        uint256 subscriptionStartsAt;
        uint256 subscriptionEndsAt;
    }

    error InvalidToken();

    event PaymentReceived(address indexed _token, address indexed _subsciber, uint256 indexed _amount);
    event SubscriptionFeeUSDUpdated(string _mssg, uint256 indexed _subscriptionFeeUSD);
    event SubscriptionPeriodUpdated(string _mssg, uint256 indexed _subscriptionPeriod);
    event ColdWalletUpdated(address indexed _coldWallet);

    constructor(
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
        coldWallet = _coldWallet;
        bnb = _bnb;
        usdc = _usdc;
        usdt = _usdt;
        wbtc = _wbtc;

        priceFeedBNBUSD = AggregatorV3Interface(_priceFeedBNBUSD);
        priceFeedETHUSD = AggregatorV3Interface(_priceFeedETHUSD);
        priceFeedWBTCUSD = AggregatorV3Interface(_priceFeedWBTCUSD);
    }

    function getSubscriptionFee(address _token) public view returns(uint256){
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

    function paySubscription(address _token) external {
        uint256 amount;
        if(_token == bnb) {
            amount = getSubscriptionFee(bnb);
            IERC20(bnb).safeTransferFrom(msg.sender, address(this), amount);
            balanceBNB = balanceBNB +  amount;
        } else if(_token == usdc) {
            amount = subscriptionFeeUSD * 10 ** 6;
            IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
            balanceUSDC = balanceUSDC +  subscriptionFeeUSD;
        } else if(_token == usdt) {
            amount = subscriptionFeeUSD * 10 ** 6;
            IERC20(usdt).safeTransferFrom(msg.sender, address(this), amount); 
            balanceUSDT = balanceUSDT +  subscriptionFeeUSD;
        } else if(_token == wbtc) {
            amount = getSubscriptionFee(wbtc);
            IERC20(wbtc).safeTransferFrom(msg.sender, address(this), amount);
            balanceWBTC = balanceWBTC +  amount;
        } else {
            revert InvalidToken();
        }

        userToSubscription[msg.sender].subscriptionStartsAt = block.timestamp;
        userToSubscription[msg.sender].subscriptionEndsAt = block.timestamp + (subscriptionPeriod * 1 days);

        emit PaymentReceived(_token, msg.sender, amount);
    }

    function payWithETH() external payable {
        require(msg.value > 0, "Amount must be greater than zero");
        balanceETH = balanceETH + msg.value;

        emit PaymentReceived(address(0), msg.sender, msg.value);
    }

    function isSubscribed(address _user) public view returns (bool){
        return block.timestamp < userToSubscription[_user].subscriptionEndsAt; 
    }

    function getSubscriptionData(address _user) external view returns (Subscription memory){
        Subscription memory subscription = Subscription(
            userToSubscription[_user].subscriptionStartsAt,
            userToSubscription[_user].subscriptionEndsAt
        );
        return subscription;
    }

    function updateSubscriptionFeeUSD(uint256 _subscriptionFeeUSD) external onlyOwner{
        subscriptionFeeUSD = _subscriptionFeeUSD;

        emit SubscriptionFeeUSDUpdated("SubscriptionFeeUSD Updated", _subscriptionFeeUSD);
    }

    function updateSubscriptionPeriod(uint256 _subscriptionPeriod) external onlyOwner{
        subscriptionPeriod = _subscriptionPeriod;
        
       emit SubscriptionPeriodUpdated("Subscription Period Updated", _subscriptionPeriod);
    }

    function updateColdWallet(address _coldWallet) external onlyOwner {
        coldWallet = _coldWallet;

        emit ColdWalletUpdated(_coldWallet);
    }

    function withdraw() external onlyOwner {
        
    }
}
