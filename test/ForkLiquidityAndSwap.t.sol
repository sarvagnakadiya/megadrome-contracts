// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IRouter, Router} from "contracts/Router.sol";
import {PoolFactory} from "contracts/factories/PoolFactory.sol";
import {IPool} from "contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";

contract ForkLiquidityAndSwapTest is Test {
    // Monad deployed contract addresses (from DeployCore-Monad.json)
    address constant ROUTER = 0xE6fF0a5231D487F073889bcf699dA90423ECA6FB;
    address constant POOL_FACTORY = 0x08A1739A3Fdc826eBC57EbD25718A25Cb445f2a8;

    // Monad token addresses
    address constant WMONAD = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address constant USDC = 0xEE8c0E9f1BFFb4Eb878d8f15f368A02a35481242;

    // Pool address (from DeployGaugesAndPools-Monad.json, WMONAD/USDC volatile)
    address constant POOL = 0xf7f9006427800b50ce6179352d09b8C506130370;

    Router router;
    PoolFactory poolFactory;
    address user;

    uint256 constant WMONAD_AMOUNT = 10 ether;
    uint256 constant USDC_AMOUNT = 10_000 * 1e6;
    uint256 constant SWAP_AMOUNT = 1 ether;

    function setUp() public {
        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));

        router = Router(payable(ROUTER));
        poolFactory = PoolFactory(POOL_FACTORY);
        user = makeAddr("user");

        // Fund user with WMONAD via native deposit
        vm.deal(user, WMONAD_AMOUNT + SWAP_AMOUNT);
        vm.prank(user);
        IWETH(WMONAD).deposit{value: WMONAD_AMOUNT + SWAP_AMOUNT}();

        // Fund user with USDC
        deal(USDC, user, USDC_AMOUNT);
    }

    function test_addLiquidityAndSwap() public {
        // --- Step 1: Add Liquidity ---
        vm.startPrank(user);

        IERC20(WMONAD).approve(address(router), WMONAD_AMOUNT);
        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            WMONAD,
            USDC,
            false,
            WMONAD_AMOUNT,
            USDC_AMOUNT,
            0,
            0,
            user,
            block.timestamp
        );

        vm.stopPrank();

        assertGt(liquidity, 0, "Should receive LP tokens");
        assertGt(amountA, 0, "Should deposit WMONAD");
        assertGt(amountB, 0, "Should deposit USDC");

        console.log("=== Liquidity Added ===");
        console.log("WMONAD deposited:", amountA);
        console.log("USDC deposited:", amountB);
        console.log("LP tokens:", liquidity);

        // Verify pool reserves
        (uint256 reserve0, uint256 reserve1, ) = IPool(POOL).getReserves();
        assertGt(reserve0, 0, "Reserve0 should be non-zero");
        assertGt(reserve1, 0, "Reserve1 should be non-zero");

        // --- Step 2: Swap WMONAD -> USDC ---
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: WMONAD,
            to: USDC,
            stable: false,
            factory: address(poolFactory)
        });

        uint256[] memory expectedAmounts = router.getAmountsOut(SWAP_AMOUNT, routes);
        uint256 expectedOut = expectedAmounts[1];
        assertGt(expectedOut, 0, "Expected output should be non-zero");

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        vm.startPrank(user);
        IERC20(WMONAD).approve(address(router), SWAP_AMOUNT);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            SWAP_AMOUNT,
            0,
            routes,
            user,
            block.timestamp
        );
        vm.stopPrank();

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        uint256 received = usdcAfter - usdcBefore;

        assertEq(amounts[0], SWAP_AMOUNT, "Input amount should match");
        assertGt(amounts[1], 0, "Output amount should be non-zero");
        assertEq(received, amounts[1], "Received should match router output");

        console.log("=== Swap Executed ===");
        console.log("WMONAD in:", amounts[0]);
        console.log("USDC out:", amounts[1]);
        console.log("Expected:", expectedOut);

        // --- Step 3: Verify final pool state ---
        (uint256 r0, uint256 r1, ) = IPool(POOL).getReserves();
        console.log("=== Final Pool State ===");
        console.log("Reserve0:", r0);
        console.log("Reserve1:", r1);
        console.log("LP balance:", IERC20(POOL).balanceOf(user));
    }
}
