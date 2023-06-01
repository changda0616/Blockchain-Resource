pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "./contracts/SimpleSwap.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Deploy is Script {
    function run() external  {
        uint256 key = vm.envUint('pk');
        vm.startBroadcast(key);
        IERC20 token1 = new ERC20("token1", "t1");
        IERC20 token2 = new ERC20("token2", "t2");
        
        SimpleSwap simpleSwap = new SimpleSwap(address(token1), address(token2));
        vm.stopBroadcast();
    }
}