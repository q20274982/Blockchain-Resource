pragma solidity 0.8.20;

import "forge-std/Script.sol";
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { SimplePriceOracle } from "compound-protocol/contracts/SimplePriceOracle.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";
import { UnitrollerAdminStorage } from "compound-protocol/contracts/ComptrollerStorage.sol";
import { GovernorBravoDelegator } from "compound-protocol/contracts/Governance/GovernorBravoDelegator.sol";
import { GovernorBravoDelegateStorageV2 } from "compound-protocol/contracts/Governance/GovernorBravoInterfaces.sol";
import { CToken } from "compound-protocol/contracts/CToken.sol";
import { Comp } from "compound-protocol/contracts/Governance/Comp.sol";
import { GovernorBravoDelegate } from "src/GovernorBravoDelegate.sol";
import { Timelock } from "src/Timelock.sol";

contract GovernanceScript is Script {
  Unitroller constant public unitroller = Unitroller(payable(0x63d005EA741704dDA3d74Cb54a5bf6F3b1Dc86DB));
  CErc20Delegator constant public cToken = CErc20Delegator(payable(0xdc25E4DDd051De774566ACC5a7442284e659FeeC));
  GovernorBravoDelegator constant public bravo = GovernorBravoDelegator(payable(0x561adf66bEf90969783d6E6D118e16Fd6856F862));
  Timelock constant public timelock = Timelock(payable(0x93C485BC5F028C36dFf0B9add0dCAfb080cb7dd7));
  Comp constant public comp = Comp(payable(0x8dCb0C9a616bEdcf70eB826BA8Cfc8a11b420EE7));

  address PKM = vm.envAddress('PUBLIC_KEY_MAIN');
  uint256 SKM = vm.envUint('PRIVATE_KEY_MAIN');

  address PKS = vm.envAddress('PUBLIC_KEY_SECN');
  uint256 SKS = vm.envUint('PRIVATE_KEY_SECN');

  function delegateVotingPower() public {
    // TODO: Distribute Comp into two addresses, delegate one address to yourself,
    // and delegate the other address to your team member.

    vm.startBroadcast(SKS);
    comp.transfer(PKM, 100e18);
    comp.delegate(PKS);
    vm.stopBroadcast();

    vm.startBroadcast(SKM);
    comp.delegate(PKS);
    vm.stopBroadcast();

    console.logUint(comp.balanceOf(PKM));
    console.logUint(comp.balanceOf(PKS));

    uint96 votingPower = comp.getCurrentVotes(PKS);
    console.logUint(votingPower / 1e18);
  }

  function propose() public {
    // TODO: Submit a proposal, remember that your address requires 100 COMP of voting power.
    vm.startBroadcast(SKS);
    address[] memory targets = new address[](1);
    targets[0] = address(unitroller);
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    string[] memory signatures = new string[](1);
    signatures[0] = "_supportMarket(CToken)";
    bytes[] memory data = new bytes[](1);
    data[0] = abi.encode(address(cToken));
    string memory description = "Support cToken";
    
    (bool isSuccess, bytes memory _data) = address(bravo).call(abi.encodeWithSignature("propose(address[],uint256[],string[],bytes[],string)", targets, values, signatures, data, description));
    console.logBool(isSuccess);
    (uint256 proposalId) = abi.decode(_data, (uint256));
    console.logUint(proposalId);
    vm.stopBroadcast();
  }

  function vote() public {
    // TODO: Vote for proposals that you prefer.

  }

  function queueProposal() public {
    // TODO: Send the approved proposal to the timelock.

  }

  function executeProposal() public {
    // TODO: Execute the proposal in the timelock.

  }
}
