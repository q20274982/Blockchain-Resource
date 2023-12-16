// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {Unitroller} from "compound/Unitroller.sol";
import {ComptrollerG7} from "compound/ComptrollerG7.sol";
import {SimplePriceOracle} from "compound/SimplePriceOracle.sol";
import {CErc20Delegate} from "compound/CErc20Delegate.sol";
import {CErc20Delegator} from "compound/CErc20Delegator.sol";
import {CToken} from "compound/CToken.sol";
import {WhitePaperInterestRateModel} from "compound/WhitePaperInterestRateModel.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/Test.sol";

contract CompoundHWTest is Test {

    Unitroller public unitroller;
    ComptrollerG7 public comptroller;
    ComptrollerG7 public unitrollerProxy;
    SimplePriceOracle public priceOracle;
    WhitePaperInterestRateModel	public whitePaper;

    ERC20 public tokenA;
    CErc20Delegate public cTokenADelegate;
    CErc20Delegator cTokenA;

    Token tokenB;
    CErc20Delegate cTokenBDelegate;
    CErc20Delegator cTokenB;

    address public user1;
    address public user2;

    function setUp() public {
        user1 = makeAddr("user1");
        
        // setup dependencies
        priceOracle = new SimplePriceOracle();
        whitePaper = new WhitePaperInterestRateModel(0, 0); // 使用 `WhitePaperInterestRateModel` 作為利率模型，利率模型合約中的借貸利率設定為 0%
        tokenA = new Token("tokenA"); // 自行部署一個 cERC20 的 underlying ERC20 token，decimals 為 18

        // initial Unitroller
        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        unitrollerProxy = ComptrollerG7(address(unitroller));
        unitroller._setPendingImplementation(address(comptroller));

        comptroller._become(unitroller);

        unitrollerProxy._setPriceOracle(priceOracle); // 使用 `SimplePriceOracle` 作為 Oracle
        // unitrollerProxy._setMaxAssets(20);
        // unitrollerProxy._setLiquidationIncentive(1080000000000000000);


        // initial CErc20Delegator
        cTokenADelegate = new CErc20Delegate();
        cTokenA = new CErc20Delegator(
            address(tokenA), // underlying
            unitrollerProxy, // comptroller
            WhitePaperInterestRateModel(whitePaper), // interestRateModel
            1 * 1e18, // initialExchangeRateMantissa, 初始 exchangeRate 為 1:1
            "Compound TokenA", // name
            "cTokenA", // symbol
            18, // decimals, cERC20 的 decimals 皆為 18
            payable(address(this)), // admin
            address(cTokenADelegate), // implementation
            bytes("0x") // becomeImplementationData
        );
        
        // cTokenA._setImplementation(address(cTokenADelegate), false, "0x");
        // cTokenA._setReserveFactor(250000000000000000);
    }    

    // 2. 讓 User1 mint/redeem cERC20，請透過 Foundry test case (你可以繼承上題的 script 或是用其他方式實現部署) 實現以下場景：
    // * User1 使用 100 顆（100 * 10^18） ERC20 去 mint 出 100 cERC20 token，再用 100 cERC20 token redeem 回 100 顆 ERC20 
    function testUserMintAndRedeem() public {
        uint256 amount = 100 * 1e18;
        deal(address(tokenA), user1, amount);

        // add cTokenA to market list
        unitrollerProxy._supportMarket(CToken(address(cTokenA)));

        vm.startPrank(user1);
        tokenA.approve(address(cTokenA), amount);
        cTokenA.mint(amount);

        // assert user1's cTokenA balance equal to amount
        assertEq(cTokenA.balanceOf(user1), amount);

        cTokenA.redeem(amount);
        // assert user1's Token balance equal to amount
        assertEq(tokenA.balanceOf(user1), amount);
        vm.stopPrank();
    }

    // 3. 讓 User1 borrow/repay
    // * [x] 部署第二份 cERC20 合約，以下稱它們的 underlying tokens 為 token A 與 token B。
    // * [x] 在 Oracle 中設定一顆 token A 的價格為 $1，一顆 token B 的價格為 $100
    // * [x] Token B 的 collateral factor 為 50%
    // * [x] User1 使用 1 顆 token B 來 mint cToken
    // * [x] User1 使用 token B 作為抵押品來借出 50 顆 token A
    // 4. 延續 (3.) 的借貸場景，調整 token B 的 collateral factor，讓 User1 被 User2 清算
    // 5. 延續 (3.) 的借貸場景，調整 oracle 中 token B 的價格，讓 User1 被 User2 清算
    function testUserBorrowAndRepay() public {
        tokenB = new Token("tokenB"); // 自行部署一個 cERC20 的 underlying ERC20 token，decimals 為 18
        cTokenBDelegate = new CErc20Delegate();

        // 部署第二份 cERC20 合約，以下稱它們的 underlying tokens 為 token A 與 token B。
        cTokenB = new CErc20Delegator(
            address(tokenB), // underlying
            unitrollerProxy, // comptroller
            WhitePaperInterestRateModel(whitePaper), // interestRateModel
            1 * 1e18, // initialExchangeRateMantissa, 初始 exchangeRate 為 1:1
            "Compound TokenB", // name
            "cTokenB", // symbol
            18, // decimals, cERC20 的 decimals 皆為 18
            payable(address(this)), // admin
            address(cTokenBDelegate), // implementation
            bytes("0x") // becomeImplementationData
        );

        unitrollerProxy._supportMarket(CToken(address(cTokenA)));
        unitrollerProxy._supportMarket(CToken(address(cTokenB)));

        // 在 Oracle 中設定一顆 token A 的價格為 $1，一顆 token B 的價格為 $100
        priceOracle.setUnderlyingPrice(CToken(address(cTokenA)), 1 * 1e18);
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 100 * 1e18);

        // Token B 的 collateral factor 為 50%
        unitrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 0.5e18);


        user2 = makeAddr("user2");
        vm.startPrank(user2);
        deal(address(tokenA), user2, 200e18);
        deal(address(tokenB), user2, 200e18);
        tokenA.approve(address(cTokenA), 200e18);
        tokenB.approve(address(cTokenB), 200e18);
        cTokenA.mint(100e18);
        cTokenB.mint(100e18);
        vm.stopPrank();

        // User1 使用 1 顆 token B 來 mint cToken
        vm.startPrank(user1);
        uint256 amount = 1 * 1e18;
        deal(address(tokenB), user1, amount);
        tokenB.approve(address(cTokenB), amount);
        cTokenB.mint(amount);

        // User1 使用 token B 作為抵押品來借出 50 顆 token A
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        unitrollerProxy.enterMarkets(cTokens);

        uint256 borrowAmount = 50 * 1e18;
        cTokenA.borrow(borrowAmount);
        // assertEq(errorCode, 0);
        
        // assert user1's cTokenB balance equal to amount
        assertEq(tokenA.balanceOf(user1), borrowAmount);
        vm.stopPrank();
    }

    // 4. 延續 (3.) 的借貸場景，調整 token B 的 collateral factor，讓 User1 被 User2 清算
    function testCollateralFactorToLiquidateBorrow() public {
        testUserBorrowAndRepay();

        unitrollerProxy._setCloseFactor(0.5e18);
        unitrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 0.4e18);
        vm.startPrank(user2);

        uint256 repayAmount = 50 * 0.5e18;
        uint errorCode = cTokenA.liquidateBorrow(user1, repayAmount, cTokenB);
        assertEq(errorCode, 0);

        vm.stopPrank();
    }

    // 5. 延續 (3.) 的借貸場景，調整 oracle 中 token B 的價格，讓 User1 被 User2 清算
    function testOraclePriceToLiquidateBorrow() public {
        testUserBorrowAndRepay();

        unitrollerProxy._setCloseFactor(0.5e18);
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 80 * 1e18);

        vm.startPrank(user2);

        uint256 repayAmount = 50 * 0.5e18;
        uint errorCode = cTokenA.liquidateBorrow(user1, repayAmount, cTokenB);
        assertEq(errorCode, 0);

        vm.stopPrank();
    }
}

contract Token is ERC20 {
    constructor(string memory name) ERC20(name, name) {}
}