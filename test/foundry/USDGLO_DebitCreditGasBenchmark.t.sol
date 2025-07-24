// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "./Helper.sol";

// Based on https://github.com/mento-protocol/mento-core/blob/develop/test/unit/tokens/StableTokenV2.t.sol
contract USDGLO_DebitCreditGasBenchmark_Test is Test {
    GloDollarV4 private usdglo;

    address private constant admin =
        address(0x284797b8dA4909755FCA06Fa02BF81c0dae9a0E3);
    address private constant minter =
        address(0x18216283a5045E8719D0F8B3617Ab6B14fC4d479);

    address holder0 = address(0x2001);

    address feeRecipient = address(0x3001);
    address gatewayFeeRecipient = address(0x3002);
    address communityFund = address(0x3003);

    uint256 private constant MAX_ALLOWED_SUPPLY = (uint256(1) << 255) - 1;

    function setUp() public {
        GloDollarV4 implementation = new GloDollarV4();
        UUPSProxy proxy = new UUPSProxy(address(implementation), "");

        // wrap in ABI to support easier calls
        usdglo = GloDollarV4(address(proxy));

        usdglo.initialize(admin);

        vm.startPrank(admin);
        usdglo.grantRole(usdglo.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.startPrank(minter);
        usdglo.mint(holder0, 1000);
        usdglo.mint(feeRecipient, 1000);
        usdglo.mint(communityFund, 1000);
        usdglo.mint(gatewayFeeRecipient, 1000);

        vm.stopPrank();
    }

    function test_debitCreditGasFees() public {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;

        vm.prank(address(0));
        usdglo.debitGasFees(holder0, 100);
        vm.stopPrank();

        vm.prank(address(0));
        usdglo.creditGasFees(
            holder0,
            feeRecipient,
            gatewayFeeRecipient,
            communityFund,
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );
        vm.stopPrank();
    }
}
