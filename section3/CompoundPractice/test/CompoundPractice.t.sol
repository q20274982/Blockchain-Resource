// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { EIP20Interface } from "compound-protocol/contracts/EIP20Interface.sol";
import { CErc20 } from "compound-protocol/contracts/CErc20.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import "test/helper/CompoundPracticeSetUp.sol";

interface IBorrower {
  function borrow() external;
}

contract CompoundPracticeTest is CompoundPracticeSetUp {
  EIP20Interface public USDC = EIP20Interface(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
  address public user;

  IBorrower public borrower;

  function setUp() public override {
    super.setUp();

    // Deployed in CompoundPracticeSetUp helper
    borrower = IBorrower(borrowerAddress);
    vm.makePersistent(address(borrower));

    vm.createSelectFork('https://rpc.ankr.com/eth');
    vm.rollFork(18_684_410);

    user = makeAddr("User");  

    uint256 initialBalance = 10000 * 10 ** USDC.decimals();
    deal(address(USDC), user, initialBalance);

    vm.label(address(cUSDC), "cUSDC");
    vm.label(borrowerAddress, "Borrower");
  }

  function test_compound_mint_interest() public {
    uint bal = 10000 * 10 ** USDC.decimals();
    // TODO: 1. Mint some cUSDC with USDC
    vm.startPrank(user); 
    USDC.approve(address(cUSDC), bal);
    uint code = cUSDC.mint(bal);
    // TODO: 2. Modify block state to generate interest
    vm.rollFork(18_684_440);
    // TODO: 3. Redeem and check the redeemed amount
    uint256 code2 = cUSDC.redeem(cUSDC.balanceOf(address(user)));
    assertGt(USDC.balanceOf(address(user)), bal);
    vm.stopPrank();
  }

  function test_compound_mint_interest_with_borrower() public {
    uint bal = 10000 * 10 ** USDC.decimals();
    vm.startPrank(user); 
    // TODO: 1. Mint some cUSDC with USDC
    USDC.approve(address(cUSDC), bal);
    uint code = cUSDC.mint(bal);
    // 2. Borrower contract will borrow some USDC
    borrower.borrow();

    // TODO: 3. Modify block state to generate interest
    vm.rollFork(18_684_440);

    // TODO: 4. Redeem and check the redeemed amount
    uint256 code2 = cUSDC.redeem(cUSDC.balanceOf(address(user)));
    assertGt(USDC.balanceOf(address(user)), bal);
    vm.stopPrank();
  }

  function test_compound_mint_interest_with_borrower_advanced() public {
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address cDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    uint bal = 10000 * 10 ** USDC.decimals();
    vm.startPrank(user); 
    // TODO: 1. Mint some cUSDC with USDC
    USDC.approve(address(cUSDC), bal);
    uint code = cUSDC.mint(bal);
    vm.stopPrank();

    address anotherBorrower = makeAddr("Another Borrower");
    // TODO: 2. Borrow some USDC with another borrower
    // 1. 先 Approve
    // 2. Mint
    // 3. enterMarkets
    // 4. borrow
    vm.startPrank(anotherBorrower);
    uint256 initialBalance = 100000000 * 10 ** USDC.decimals();
    deal(DAI, anotherBorrower, initialBalance);

    EIP20Interface(DAI).approve(address(cDAI), initialBalance);
    uint code2 = CErc20(cDAI).mint(initialBalance);
    address[] memory cTokens = new address[](1);
    cTokens[0] = cDAI;
    uint[] memory code5 = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B).enterMarkets(cTokens);
    uint code4 = CErc20(cUSDC).borrow(10000 * 10 ** USDC.decimals());
    vm.stopPrank();
    // TODO: 3. Modify block state to generate interest
    vm.rollFork(18_684_440);
    // TODO: 4. Redeem and check the redeemed amount
    vm.startPrank(user); 
    uint256 code3 = cUSDC.redeem(cUSDC.balanceOf(address(user)));
    assertGt(USDC.balanceOf(address(user)), bal);
    vm.stopPrank();
    console.logUint(USDC.balanceOf(address(user)));
    console.logUint(code);
    console.logUint(code2);
    console.logUint(code3);
    console.logUint(code4);
  }
}
