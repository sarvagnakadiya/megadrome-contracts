// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {Base} from "test/Base.sol";
import {IRouter, Router} from "contracts/Router.sol";
import {PoolFactory} from "contracts/factories/PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Script to swap tokens in a pool
contract Swap is Base {
    address public poolAddress;
    address public tokenIn;
    address public tokenOut;
    bool public stable;
    uint256 public amountIn;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");

        // Load deployed contract addresses
        _loadContracts();

        // Get pool tokens and type
        (tokenIn, tokenOut) = _getPoolTokens(poolAddress);
        stable = _isStablePool(poolAddress);
        amountIn = vm.envOr("AMOUNT_IN", uint256(1 ether));

        // Build route
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: stable,
            factory: address(factory)
        });

        // Get expected output and calculate minimum (95% slippage tolerance)
        uint256[] memory amountsOut = router.getAmountsOut(amountIn, routes);
        uint256 expectedAmountOut = amountsOut[amountsOut.length - 1];
        uint256 amountOutMin = (expectedAmountOut * 95) / 100;

        // Execute swap
        vm.startBroadcast(deployerPrivateKey);
        IERC20(tokenIn).approve(address(router), amountIn);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            routes,
            msg.sender,
            block.timestamp + 1800
        );
        vm.stopBroadcast();

        // Log results
        console.log("=== Swap Executed ===");
        console.log("Pool:", poolAddress);
        console.log("Token In:", tokenIn);
        console.log("Token Out:", tokenOut);
        console.log("Stable:", stable);
        console.log("Amount In:", amounts[0]);
        console.log("Amount Out:", amounts[1]);
        console.log("Expected Amount Out:", expectedAmountOut);
        console.log("Slippage:", _calculateSlippage(amounts[1], expectedAmountOut));
    }

    /// @notice Load deployed contract addresses and pool
    function _loadContracts() internal {
        string memory root = vm.projectRoot();
        string memory coreJson = vm.readFile(string.concat(root, "/script/constants/output/DeployCore-Monad.json"));
        router = Router(payable(vm.parseJsonAddress(coreJson, ".Router")));
        factory = PoolFactory(vm.parseJsonAddress(coreJson, ".PoolFactory"));

        string memory poolJson = vm.readFile(string.concat(root, "/script/constants/output/DeployGaugesAndPools-Monad.json"));
        address[] memory pools = vm.parseJsonAddressArray(poolJson, ".pools");
        require(pools.length > 0, "No pools found");
        poolAddress = pools[0];
    }

    /// @notice Get token addresses from pool
    function _getPoolTokens(address pool) internal view returns (address token0, address token1) {
        bytes memory token0Data = abi.encodeWithSignature("token0()");
        bytes memory token1Data = abi.encodeWithSignature("token1()");

        (bool success0, bytes memory result0) = pool.staticcall(token0Data);
        (bool success1, bytes memory result1) = pool.staticcall(token1Data);

        require(success0 && success1, "Failed to get pool tokens");

        token0 = abi.decode(result0, (address));
        token1 = abi.decode(result1, (address));
    }

    /// @notice Check if pool is stable or volatile
    function _isStablePool(address pool) internal view returns (bool) {
        bytes memory stableData = abi.encodeWithSignature("stable()");
        (bool success, bytes memory result) = pool.staticcall(stableData);

        require(success, "Failed to get pool type");

        return abi.decode(result, (bool));
    }

    /// @notice Calculate slippage percentage
    function _calculateSlippage(uint256 actual, uint256 expected) internal pure returns (uint256) {
        if (expected == 0) return 0;
        if (actual >= expected) return 0;
        return ((expected - actual) * 10000) / expected; // Returns basis points
    }
}
