// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../contracts/SimpleSwap.sol";
import { TestERC20 } from "../../contracts/test/TestERC20.sol";


contract SimpleSwapScript is Script {
  function run() external {
    vm.startBroadcast();
    TestERC20 tokenA = new TestERC20("token A", "TKA");
    TestERC20 tokenB = new TestERC20("token B", "TKB");
    new SimpleSwap(address(tokenA), address(tokenB));
    vm.stopBroadcast();
  }
}