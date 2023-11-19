// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Slots } from "./utils/Slots.sol";
import { Proxy } from "./utils/Proxy.sol";

contract ERC1967Proxy is Slots, Proxy {

  bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
  bytes32 constant ADMIN_SLOT = bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1);
  
  constructor(address _impl, bytes memory _data) {
    // TODO:
    // 1. set the implementation address at bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    _setSlotToAddress(IMPLEMENTATION_SLOT, _impl);
    // 2. set admin owner address at bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
    _setSlotToAddress(ADMIN_SLOT, msg.sender);
    // 3. if data exist, then initialize proxy with _data
    if (_data.length > 0) {
      (bool success,) = _impl.delegatecall(_data);
      require(success, "init fail");
    }
  }

  function bytes32ToAddress(bytes32 _bytes32) internal pure returns (address) {
    return address(uint160(uint256(_bytes32)));
  }

  function implementation() public view returns (address impl) {
    // TODO: return the implementation address
    return bytes32ToAddress(IMPLEMENTATION_SLOT);
  }

  modifier onlyAdmin {
    // TODO: check if msg.sender is equal to admin owner address
    address _admin = _getSlotToAddress(ADMIN_SLOT);
    require(msg.sender == _admin, "ERC1967Proxy: admin only");
    _;
  }

  function upgradeToAndCall(address newImplementation, bytes memory _data) external onlyAdmin {
    // TODO:
    // 1. upgrade the implementation address
    // 2. initialize proxy, if data exist, then initialize proxy with _data
    _setSlotToAddress(IMPLEMENTATION_SLOT, newImplementation);
    if (_data.length > 0) {
      (bool success,) = newImplementation.delegatecall(_data);
      require(success);
    }
  }

  fallback() external payable virtual {
    _delegate(implementation());
  }

  receive() external payable {
    _delegate(implementation());
  }
}