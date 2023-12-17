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
import {
	IFlashLoanSimpleReceiver,
	IPoolAddressesProvider,
	IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import "forge-std/Test.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract AAVEFlashLoanTest is Test {

    Unitroller public unitroller;
    ComptrollerG7 public comptroller;
    ComptrollerG7 public unitrollerProxy;
    SimplePriceOracle public priceOracle;
    WhitePaperInterestRateModel	public whitePaper;

    address UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    CErc20Delegate cUNIDelegate;
    CErc20Delegator cUNI;

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    CErc20Delegate cUSDCDelegate;
    CErc20Delegator cUSDC;

    address public user1;
    address public user2;

    function setUp() public {
        // Fork Ethereum mainnet at block  17465000
        vm.createSelectFork(vm.envString('MAINNET_RPC_URL'));
        vm.rollFork(17_465_000);

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // setup dependencies
        priceOracle = new SimplePriceOracle();
        whitePaper = new WhitePaperInterestRateModel(0, 0); // 使用 `WhitePaperInterestRateModel` 作為利率模型，利率模型合約中的借貸利率設定為 0%

        // initial Unitroller
        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        unitrollerProxy = ComptrollerG7(address(unitroller));
        unitroller._setPendingImplementation(address(comptroller));

        comptroller._become(unitroller);

        // 使用 USDC 以及 UNI 代幣來作為 token A 以及 Token B
        // initial USDC CErc20Delegator
        cUSDCDelegate = new CErc20Delegate();
        cUSDC = new CErc20Delegator(
            USDC, // underlying
            unitrollerProxy, // comptroller
            WhitePaperInterestRateModel(whitePaper), // interestRateModel
            1 * 1e6, // initialExchangeRateMantissa, 初始 exchangeRate 為 1:1
            "Compound USDC", // name
            "cUSDC", // symbol
            18, // decimals, cERC20 的 decimals 皆為 18
            payable(address(this)), // admin
            address(cUSDCDelegate), // implementation
            bytes("0x") // becomeImplementationData
        );

        // initial UNI CErc20Delegator
        cUNIDelegate = new CErc20Delegate();
        cUNI = new CErc20Delegator(
            UNI, // underlying
            unitrollerProxy, // comptroller
            WhitePaperInterestRateModel(whitePaper), // interestRateModel
            1 * 1e18, // initialExchangeRateMantissa, 初始 exchangeRate 為 1:1
            "Compound UNI", // name
            "cUNI", // symbol
            18, // decimals, cERC20 的 decimals 皆為 18
            payable(address(this)), // admin
            address(cUNIDelegate), // implementation
            bytes("0x") // becomeImplementationData
        );

        // 使用 `SimplePriceOracle` 作為 Oracle
        unitrollerProxy._setPriceOracle(priceOracle);

        // Close factor 設定為 50%
        unitrollerProxy._setCloseFactor(0.5e18);
        
        // Liquidation incentive 設為 8% (1.08 * 1e18)
        unitrollerProxy._setLiquidationIncentive(1.08 * 1e18);

        unitrollerProxy._supportMarket(CToken(address(cUSDC)));
        unitrollerProxy._supportMarket(CToken(address(cUNI)));

        // 在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1 * 1e30);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5 * 1e18);

        // 設定 UNI 的 collateral factor 為 50%
        unitrollerProxy._setCollateralFactor(CToken(address(cUNI)), 0.5e18);

        // 初始化資金
        deal(USDC, address(this), 1000000 * 1e6);
        ERC20(USDC).approve(address(cUSDC), 1000000 * 1e6);
        cUSDC.mint(1000000 * 1e6);
    }    

    // 6. 請使用 Foundry 的 fork testing 模式撰寫測試，並使用 AAVE v3 的 [Flash loan](https://docs.aave.com/developers/guides/flash-loans) 來清算 User1，請遵循以下細節：
    //* [x] Fork Ethereum mainnet at block  17465000([Reference](https://book.getfoundry.sh/forge/fork-testing#examples))
    //* [x] cERC20 的 decimals 皆為 18，初始 exchangeRate 為 1:1
    //* [x] Close factor 設定為 50%
    //* [x] Liquidation incentive 設為 8% (1.08 * 1e18)
    //* [x] 使用 USDC 以及 UNI 代幣來作為 token A 以及 Token B
    //* [x] 在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
    //* [x] 設定 UNI 的 collateral factor 為 50%
    //* [x] User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
    //* [x] 將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
    //* [x] 可以自行檢查清算 50% 後是不是大約可以賺 63 USDC
    function testAAVEFlashLoan() public {

        // User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
        vm.startPrank(user1);
        uint256 depositAmount = 1000 * 1e18;
        deal(UNI, user1, depositAmount);
        ERC20(UNI).approve(address(cUNI), depositAmount);
        cUNI.mint(depositAmount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        unitrollerProxy.enterMarkets(cTokens);

        uint256 borrowAmount = 2500 * 1e6;
        cUSDC.borrow(borrowAmount);

        assertEq(ERC20(USDC).balanceOf(user1), borrowAmount);
        vm.stopPrank();

        // 將 UNI 價格改為 $4 使 User1 產生 Shortfall
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4 * 1e18);

		// 並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
		vm.startPrank(user2);		
		AaveFlashLoan flashLoan = new AaveFlashLoan();
		CallData memory data = CallData(cUSDC, cUNI, user1);
		flashLoan.execute(data);

        flashLoan.claim();
		vm.stopPrank();
        
        // 可以自行檢查清算 50% 後是不是大約可以賺 63 USDC
        uint256 reward = ERC20(USDC).balanceOf(user2);
        console.logUint(reward);
    }
}

struct CallData {
	CErc20Delegator cUSDC;
	CErc20Delegator cUNI;
	address user1;
}

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
	address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
	address constant POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    function claim() public {
        ERC20(USDC).transfer(msg.sender, ERC20(USDC).balanceOf(address(this)));
    }

	function execute(CallData calldata data) external {
		// TODO
		POOL().flashLoanSimple(
			address(this),
			USDC,
			1250e6,
			abi.encode(data),
			0
		);
	}

	function executeOperation(
		address asset,
		uint256 amount,
		uint256 premium,
		address initiator,
		bytes calldata params
	) external override returns (bool) {
		CallData memory data = abi.decode(params, (CallData));

		ERC20(asset).approve(address(data.cUSDC), amount);
		data.cUSDC.liquidateBorrow(data.user1, amount, data.cUNI);

        data.cUNI.redeem(data.cUNI.balanceOf(address(this)));

        ERC20(UNI).approve(0xE592427A0AEce92De3Edee1F18E0157C05861564, ERC20(UNI).balanceOf(address(this)));
		ISwapRouter.ExactInputSingleParams memory swapParams =
		ISwapRouter.ExactInputSingleParams({
			tokenIn: UNI,
			tokenOut: USDC,
			fee: 3000, // 0.3%
			recipient: address(this),
			deadline: block.timestamp,
			amountIn: ERC20(UNI).balanceOf(address(this)),
			amountOutMinimum: 0,
			sqrtPriceLimitX96: 0
		});

        // The call to `exactInputSingle` executes the swap.
        // swap Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564
        uint256 amountOut = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564).exactInputSingle(swapParams);

		ERC20(asset).approve(address(POOL()), amount + premium);
		return true;
	}

	function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
		return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
	}

	function POOL() public view returns (IPool) {
		return IPool(ADDRESSES_PROVIDER().getPool());
	}
}

