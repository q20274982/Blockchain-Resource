// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {Unitroller} from "compound/Unitroller.sol";
import {ComptrollerG7} from "compound/ComptrollerG7.sol";
import {SimplePriceOracle} from "compound/SimplePriceOracle.sol";
import {CErc20Delegate} from "compound/CErc20Delegate.sol";
import {CErc20Delegator} from "compound/CErc20Delegator.sol";
import {WhitePaperInterestRateModel} from "compound/WhitePaperInterestRateModel.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 請賞析 [Compound](https://docs.compound.finance/v2/) 的合約，並依序實作以下
// 1. 撰寫一個 Foundry 的 Script，該 Script 要能夠部署一個 CErc20Delegator(`CErc20Delegator.sol`，以下簡稱 cERC20)，
// 一個 Unitroller(`Unitroller.sol`) 以及他們的 Implementation 合約和合約初始化時相關必要合約。請遵循以下細節：
// * [x] cERC20 的 decimals 皆為 18
// * [x] 自行部署一個 cERC20 的 underlying ERC20 token，decimals 為 18
// * [x] 使用 `SimplePriceOracle` 作為 Oracle
// * [x] 使用 `WhitePaperInterestRateModel` 作為利率模型，利率模型合約中的借貸利率設定為 0%
// * [x] 初始 exchangeRate 為 1:1
contract CompoundHWScript is Script {

    uint256 PK = vm.envUint('HOLY_PRIVATE_KEY');

    Unitroller public unitroller;
    ComptrollerG7 public comptroller;
    ComptrollerG7 public unitrollerProxy;
    SimplePriceOracle public priceOracle;
    ERC20 public ut;
    CErc20Delegate public cUTDelegate;
    WhitePaperInterestRateModel	public whitePaper;

    function run() public {
        vm.startBroadcast(PK);

        // setup dependencies
        priceOracle = new SimplePriceOracle();
        whitePaper = new WhitePaperInterestRateModel(0, 0); // 使用 `WhitePaperInterestRateModel` 作為利率模型，利率模型合約中的借貸利率設定為 0%
        ut = new UT(); // 自行部署一個 cERC20 的 underlying ERC20 token，decimals 為 18

        // initial Unitroller
        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        unitrollerProxy = ComptrollerG7(address(unitroller));
        unitroller._setPendingImplementation(address(comptroller));

        comptroller._become(unitroller);

        unitrollerProxy._setPriceOracle(priceOracle); // 使用 `SimplePriceOracle` 作為 Oracle
        // unitrollerProxy._setCloseFactor(500000000000000000);
        // unitrollerProxy._setMaxAssets(20);
        // unitrollerProxy._setLiquidationIncentive(1080000000000000000);


        // initial CErc20Delegator
        cUTDelegate = new CErc20Delegate();
        CErc20Delegator cUT = new CErc20Delegator(
            address(ut), // underlying
            unitrollerProxy, // comptroller
            WhitePaperInterestRateModel(whitePaper), // interestRateModel
            1 * 1e18, // initialExchangeRateMantissa, 初始 exchangeRate 為 1:1
            "Compound UT", // name
            "cUT", // symbol
            18, // decimals, cERC20 的 decimals 皆為 18
            payable(address(this)), // admin
            address(cUTDelegate), // implementation
            bytes("0x") // becomeImplementationData
        );
        
        // cUT._setImplementation(address(cUTDelegate), false, "0x");
        // cUT._setReserveFactor(250000000000000000);

        vm.stopBroadcast();
    }
}

contract UT is ERC20 {
    constructor() ERC20("Underlying Token", "UT") {}
}