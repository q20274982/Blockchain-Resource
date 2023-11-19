// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import { Slots } from "./utils/Slots.sol";
import { Proxy } from "./utils/Proxy.sol";
import { console } from "forge-std/console.sol";

interface ITransparentUpgradeableProxy {
  function upgradeToAndCall(address newImplementation, bytes memory data) external;
}

contract Transparent is Slots, Proxy {

  bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
  bytes32 constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

  constructor(address _implementation, bytes memory data) {
    // TODO:
    // 1. set the implementation address at bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    _setSlotToAddress(IMPLEMENTATION_SLOT, _implementation);
    // 2. set admin owner address at bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
    _setSlotToAddress(ADMIN_SLOT, msg.sender);
    // 3. if data exist, then initialize proxy with _data
    if (data.length > 0) {
      (bool success) = _implementation.delegatecall(data);
      require(success, "Transparent: init failed");
    }
  }

  function _getAdmin() internal view returns (address) {
    // TODO: return the admin owner address
    return _getSlotToAddress(ADMIN_SLOT);
  }

  function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
    _setSlotToAddress(IMPLEMENTATION_SLOT, newImplementation);
    if (data.length > 0) {
      (bool success, ) = newImplementation.delegatecall(data);
      require(success, "Transparent: upgradeToAndCall failed");
    }
  }

  fallback() external payable {
    // TODO:
    // 1. check if msg.sender is equal to admin owner address, if no then delegatecall to implementation address
    if (msg.sender == _getAdmin()) {
      require(msg.sig == ITransparentUpgradeableProxy.upgradeToAndCall.selector, "Transparent: admin could only upgradeAndCall");
      (address impl, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
      _upgradeToAndCall(impl, data);
    } else {
      _delegate(implementation());
    }
    // 2. if yes, then check if function selector is equal to upgradeToAndCall, if no then revert with Message "Transparent: admin could only upgradeAndCall"
    // 3. if yes, upgrade the implementation address and initialize proxy with data
  }

  receive() external payable {}

  function implementation() internal view returns (address impl) {
    return _getSlotToAddress(IMPLEMENTATION_SLOT);
  }
}