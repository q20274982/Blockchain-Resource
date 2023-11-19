// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

contract Slots {

  function _setSlotToUint256(bytes32 _slot, uint256 value) internal {
    assembly {
      sstore(_slot, value)
    }
  }

  function _setSlotToAddress(bytes32 _slot, address value) internal {
    assembly {
      sstore(_slot, value)
    }
  }

  function _getSlotToAddress(bytes32 _slot) internal view returns (address value) {
    assembly {
      value := sload(_slot)
    }
  }
}

contract SlotsManipulate is Slots {

  function setAppworksWeek8(uint256 amount) external {
    // TODO: set AppworksWeek8
    _setSlotToUint256(keccak256("appworks.week8"), amount);
  }

  function setProxyImplementation(address _implementation) external {
    // TODO: set Proxy Implenmentation address
    _setSlotToAddress(bytes32(uint(keccak256("eip1967.proxy.implementation")) - 1), _implementation);
  }

  function setBeaconImplementation(address _implementation) external {
    // TODO: set Beacon Implenmentation address
    _setSlotToAddress(bytes32(uint(keccak256("eip1967.proxy.beacon")) - 1), _implementation);
  }

  function setAdminImplementation(address _who) external {
    // TODO: set Admin Implenmentation address
    _setSlotToAddress(bytes32(uint(keccak256("eip1967.proxy.admin")) - 1), _who);
  }

  function setProxiable(address _implementation) external {
    // TODO: set Proxiable Implenmentation address
    _setSlotToAddress(keccak256("PROXIABLE"), _implementation);
  }
}