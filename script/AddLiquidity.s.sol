// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";
import {Base} from "test/Base.sol";
import {IRouter, Router} from "contracts/Router.sol";
import {PoolFactory} from "contracts/factories/PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Script to add liquidity to a pool
contract AddLiquidity is Base {
    address public poolAddress;
    address public tokenA;
    address public tokenB;
    bool public stable;
    uint256 public amountA;
    uint256 public amountB;

    function run() public {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");

        // Load deployed contract addresses (Monad only)
        string memory root = vm.projectRoot();
        string memory coreDeployPath = string.concat(root, "/script/constants/output/DeployCore-Monad.json");
        string memory poolDeployPath = string.concat(root, "/script/constants/output/DeployGaugesAndPools-Monad.json");

        // Parse core contracts
        string memory coreJson = vm.readFile(coreDeployPath);
        router = Router(payable(vm.parseJsonAddress(coreJson, ".Router")));
        factory = PoolFactory(vm.parseJsonAddress(coreJson, ".PoolFactory"));

        // Parse pool addresses
        string memory poolJson = vm.readFile(poolDeployPath);
        address[] memory pools = vm.parseJsonAddressArray(poolJson, ".pools");

        require(pools.length > 0, "No pools found");
        poolAddress = pools[0]; // Use first pool

        // Get pool tokens and type
        (tokenA, tokenB) = _getPoolTokens(poolAddress);
        stable = _isStablePool(poolAddress);

        // Set amounts to add (using 1 token of each by default, 18 decimals)
        amountA = vm.envOr("AMOUNT_A", uint256(1 ether));
        amountB = vm.envOr("AMOUNT_B", uint256(1 ether));

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Approve tokens
        IERC20(tokenA).approve(address(router), amountA);
        IERC20(tokenB).approve(address(router), amountB);

        // Calculate minimum amounts (95% slippage tolerance)
        uint256 amountAMin = (amountA * 95) / 100;
        uint256 amountBMin = (amountB * 95) / 100;

        // Add liquidity
        uint256 deadline = block.timestamp + 1800; // 30 minutes
        (uint256 actualAmountA, uint256 actualAmountB, uint256 liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            stable,
            amountA,
            amountB,
            amountAMin,
            amountBMin,
            msg.sender,
            deadline
        );

        vm.stopBroadcast();

        // Log results
        console.log("=== Liquidity Added ===");
        console.log("Pool:", poolAddress);
        console.log("TokenA:", tokenA);
        console.log("TokenB:", tokenB);
        console.log("Stable:", stable);
        console.log("Amount A deposited:", actualAmountA);
        console.log("Amount B deposited:", actualAmountB);
        console.log("LP tokens received:", liquidity);

        // Save output
        string memory outputPath = string.concat(root, "/script/constants/output/AddLiquidity-Monad.json");

        vm.writeJson(vm.toString(poolAddress), outputPath, ".pool");
        vm.writeJson(vm.toString(tokenA), outputPath, ".tokenA");
        vm.writeJson(vm.toString(tokenB), outputPath, ".tokenB");
        vm.writeJson(vm.toString(stable), outputPath, ".stable");
        vm.writeJson(vm.toString(actualAmountA), outputPath, ".amountA");
        vm.writeJson(vm.toString(actualAmountB), outputPath, ".amountB");
        vm.writeJson(vm.toString(liquidity), outputPath, ".liquidity");
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
}
