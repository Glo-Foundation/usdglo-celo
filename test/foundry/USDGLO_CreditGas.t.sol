// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "./Helper.sol";

// Based on https://github.com/mento-protocol/mento-core/blob/develop/test/unit/tokens/StableTokenV2.t.sol
contract USDGLO_CreditGas_Test is Test {
    GloDollarV4 private usdglo;

    address private constant admin =
        address(0x284797b8dA4909755FCA06Fa02BF81c0dae9a0E3);
    address private constant minter =
        address(0x18216283a5045E8719D0F8B3617Ab6B14fC4d479);
    address private constant denylister =
        address(0x1135A985908639b5a218B351d16A61e084CFF7a1);
    address private constant pauser =
        address(0xeBE0ef4cF72e9ACf37F4337355b56427a09C8F89);

    address holder0 = address(0x2001);
    address holder1 = address(0x2002);
    address holder2;
    uint256 holder2Pk = uint256(0x31337);

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
        vm.stopPrank();
    }

    function test_debitGasFees_whenCallerNotVM_shouldRevert() public {
        vm.expectRevert("Only VM can call");
        usdglo.debitGasFees(holder0, 100);
    }

    function test_debitGasFees_whenCallerIsVM_shouldDebitGasFees() public {
        uint256 amount = 100;
        assertEq(usdglo.balanceOf(holder0), 1000);

        vm.prank(address(0));
        usdglo.debitGasFees(holder0, 100);

        assertEq(usdglo.balanceOf(holder0), 1000 - amount);
    }

    function test_creditGasFees_whenCallerNotVM_shouldRevert() public {
        vm.expectRevert("Only VM can call");
        usdglo.creditGasFees(
            holder0,
            feeRecipient,
            gatewayFeeRecipient,
            communityFund,
            25,
            25,
            25,
            25
        );
    }

    function test_creditGasFees_whenCalledByVm_shouldCreditFees() public {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        uint256 tokenSupplyBefore = usdglo.totalSupply();

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

        assertEq(usdglo.balanceOf(holder0), 1000 + refund);
        assertEq(usdglo.balanceOf(feeRecipient), tipTxFee);
        assertEq(usdglo.balanceOf(gatewayFeeRecipient), gatewayFee);
        assertEq(usdglo.balanceOf(communityFund), baseTxFee);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore + refund + tipTxFee + gatewayFee + baseTxFee
        );
    }

    function test_creditGasFees_whenCalledByVm_with0xFeeRecipient_shouldBurnTipTxFee()
        public
    {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        uint256 holder0InitialBalance = usdglo.balanceOf(holder0);
        uint256 tokenSupplyBefore = usdglo.totalSupply();
        uint256 newlyMinted = refund + tipTxFee + gatewayFee + baseTxFee;

        vm.prank(address(0));
        usdglo.creditGasFees(
            holder0,
            address(0),
            gatewayFeeRecipient,
            communityFund,
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );

        assertEq(usdglo.balanceOf(holder0), holder0InitialBalance + refund);
        assertEq(usdglo.balanceOf(feeRecipient), 0);
        assertEq(usdglo.balanceOf(gatewayFeeRecipient), gatewayFee);
        assertEq(usdglo.balanceOf(communityFund), baseTxFee);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore + newlyMinted - tipTxFee
        );
    }

    function test_creditGasFees_whenCalledByVm_with0xGatewayFeeRecipient_shouldBurnGateWayFee()
        public
    {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        uint256 holder0InitialBalance = usdglo.balanceOf(holder0);
        uint256 tokenSupplyBefore = usdglo.totalSupply();
        uint256 newlyMinted = refund + tipTxFee + gatewayFee + baseTxFee;

        vm.prank(address(0));
        usdglo.creditGasFees(
            holder0,
            feeRecipient,
            address(0),
            communityFund,
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );

        assertEq(usdglo.balanceOf(holder0), holder0InitialBalance + refund);
        assertEq(usdglo.balanceOf(feeRecipient), tipTxFee);
        assertEq(usdglo.balanceOf(gatewayFeeRecipient), 0);
        assertEq(usdglo.balanceOf(communityFund), baseTxFee);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore + newlyMinted - gatewayFee
        );
    }

    function test_creditGasFees_whenCalledByVm_with0xCommunityFund_shouldBurnBaseTxFee()
        public
    {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        uint256 holder0InitialBalance = usdglo.balanceOf(holder0);
        uint256 tokenSupplyBefore = usdglo.totalSupply();
        uint256 newlyMinted = refund + tipTxFee + gatewayFee + baseTxFee;

        vm.prank(address(0));
        usdglo.creditGasFees(
            holder0,
            feeRecipient,
            gatewayFeeRecipient,
            address(0),
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );

        assertEq(usdglo.balanceOf(holder0), holder0InitialBalance + refund);
        assertEq(usdglo.balanceOf(feeRecipient), tipTxFee);
        assertEq(usdglo.balanceOf(gatewayFeeRecipient), gatewayFee);
        assertEq(usdglo.balanceOf(communityFund), 0);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore + newlyMinted - baseTxFee
        );
    }

    function test_creditGasFees_whenCalledByVm_withMultiple0xRecipients_shouldBurnTheirRespectiveFees0()
        public
    {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        uint256 holder0InitialBalance = usdglo.balanceOf(holder0);
        uint256 tokenSupplyBefore0 = usdglo.totalSupply();
        uint256 newlyMinted0 = refund + tipTxFee + gatewayFee + baseTxFee;

        vm.prank(address(0));
        // gateWayFeeRecipient and communityFund both 0x
        usdglo.creditGasFees(
            holder0,
            feeRecipient,
            address(0),
            address(0),
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );

        assertEq(usdglo.balanceOf(holder0), holder0InitialBalance + refund);
        assertEq(usdglo.balanceOf(feeRecipient), tipTxFee);
        assertEq(usdglo.balanceOf(gatewayFeeRecipient), 0);
        assertEq(usdglo.balanceOf(communityFund), 0);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore0 + newlyMinted0 - gatewayFee - baseTxFee
        );
    }

    function test_creditGasFees_whenCalledByVm_withMultiple0xRecipients_shouldBurnTheirRespectiveFees1()
        public
    {
        uint256 refund = 20;
        uint256 tipTxFee = 30;
        uint256 gatewayFee = 10;
        uint256 baseTxFee = 40;
        // case with both feeRecipient and communityFund both 0x
        uint256 holder1InitialBalance = usdglo.balanceOf(holder1);
        uint256 feeRecipientBalance = usdglo.balanceOf(feeRecipient);
        uint256 gatewayFeeRecipientBalance = usdglo.balanceOf(
            gatewayFeeRecipient
        );
        uint256 communityFundBalance = usdglo.balanceOf(communityFund);
        uint256 tokenSupplyBefore1 = usdglo.totalSupply();
        uint256 newlyMinted1 = refund + tipTxFee + gatewayFee + baseTxFee;
        vm.prank(address(0));
        usdglo.creditGasFees(
            holder1,
            address(0),
            gatewayFeeRecipient,
            address(0),
            refund,
            tipTxFee,
            gatewayFee,
            baseTxFee
        );

        assertEq(usdglo.balanceOf(holder1), holder1InitialBalance + refund);
        assertEq(usdglo.balanceOf(feeRecipient), feeRecipientBalance);
        assertEq(
            usdglo.balanceOf(gatewayFeeRecipient),
            gatewayFeeRecipientBalance + gatewayFee
        );
        assertEq(usdglo.balanceOf(communityFund), communityFundBalance);
        assertEq(
            usdglo.totalSupply(),
            tokenSupplyBefore1 + newlyMinted1 - tipTxFee - baseTxFee
        );
    }
}
