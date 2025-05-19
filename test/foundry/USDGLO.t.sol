pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "./Helper.sol";

contract USDGLO_Test is Test {
    GloDollarV4 private usdglo;

    address private constant admin = address(1);
    address private constant minter = address(2);
    address private constant denylister = address(3);
    address private constant pauser = address(4);

    uint256 private constant MAX_ALLOWED_SUPPLY = (uint256(1) << 255) - 1;

    function setUp() public {
        GloDollarV4 implementation = new GloDollarV4();
        UUPSProxy proxy = new UUPSProxy(address(implementation), "");

        // wrap in ABI to support easier calls
        usdglo = GloDollarV4(address(proxy));

        usdglo.initialize(admin);
        usdglo.initializeV4();

        vm.startPrank(admin);

        usdglo.grantRole(usdglo.MINTER_ROLE(), minter);
        usdglo.grantRole(usdglo.DENYLISTER_ROLE(), denylister);
        usdglo.grantRole(usdglo.PAUSER_ROLE(), pauser);

        vm.stopPrank();
    }

    function testMint(address from, uint256 amount) public {
        vm.startPrank(minter);

        if (from == address(0)) {
            vm.expectRevert(bytes("ERC20: mint to the zero address"));

            usdglo.mint(from, amount);
        } else if (amount >= MAX_ALLOWED_SUPPLY) {
            bytes4 selector = bytes4(keccak256("IsOverSupplyCap(uint256)"));
            vm.expectRevert(
                abi.encodeWithSelector(selector, usdglo.totalSupply() + amount)
            );

            usdglo.mint(from, amount);
        } else {
            usdglo.mint(from, amount);

            assertEq(usdglo.totalSupply(), amount);
            assertEq(usdglo.balanceOf(from), amount);
        }

        vm.stopPrank();
    }

    function testBurn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 0, MAX_ALLOWED_SUPPLY);

        vm.startPrank(minter);

        usdglo.mint(minter, mintAmount);

        if (burnAmount > mintAmount) {
            vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));

            usdglo.burn(burnAmount);
        } else {
            usdglo.burn(burnAmount);

            assertEq(usdglo.totalSupply(), mintAmount - burnAmount);
            assertEq(usdglo.balanceOf(minter), mintAmount - burnAmount);
        }

        vm.stopPrank();
    }

    function testApprove(address to, uint256 amount) public {
        if (to == address(0)) {
            vm.expectRevert(bytes("ERC20: approve to the zero address"));

            bool success = usdglo.approve(to, amount);

            assertFalse(success);
            assertEq(usdglo.allowance(address(this), to), 0);
        } else {
            bool success = usdglo.approve(to, amount);

            assertTrue(success);
            assertEq(usdglo.allowance(address(this), to), amount);
        }
    }

    function testTransfer(
        address from,
        address to,
        uint256 initialBalance,
        uint256 amount
    ) public {
        vm.assume(from != address(0));
        initialBalance = bound(initialBalance, 0, MAX_ALLOWED_SUPPLY);
        amount = bound(amount, 0, initialBalance);

        vm.prank(minter);
        usdglo.mint(from, initialBalance);

        if (to == address(0)) {
            vm.expectRevert(bytes("ERC20: transfer to the zero address"));

            vm.prank(from);
            bool success = usdglo.transfer(to, amount);

            assertFalse(success);
            assertEq(usdglo.totalSupply(), initialBalance);
            assertEq(usdglo.balanceOf(from), initialBalance);
            assertEq(usdglo.balanceOf(to), 0);
        } else {
            vm.prank(from);
            bool success = usdglo.transfer(to, amount);

            assertTrue(success);
            assertEq(usdglo.totalSupply(), initialBalance);

            if (from == to) {
                assertEq(usdglo.balanceOf(from), initialBalance);
            } else {
                assertEq(usdglo.balanceOf(from), initialBalance - amount);
                assertEq(usdglo.balanceOf(to), amount);
            }
        }
    }

    function testTransferFrom(
        address sender,
        address from,
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        vm.assume(sender != address(0));
        vm.assume(from != address(0));
        amount = bound(
            amount,
            0,
            approval < MAX_ALLOWED_SUPPLY ? approval : MAX_ALLOWED_SUPPLY
        );

        vm.prank(minter);
        usdglo.mint(from, amount);

        vm.prank(from);
        usdglo.approve(sender, approval);

        if (to == address(0)) {
            vm.expectRevert(bytes("ERC20: transfer to the zero address"));

            vm.prank(sender);
            bool success = usdglo.transferFrom(from, to, amount);

            assertFalse(success);
            assertEq(usdglo.totalSupply(), amount);
            assertEq(usdglo.balanceOf(from), amount);
            assertEq(usdglo.balanceOf(to), 0);
        } else {
            vm.prank(sender);
            bool success = usdglo.transferFrom(from, to, amount);

            assertTrue(success);
            assertEq(usdglo.totalSupply(), amount);

            if (approval == type(uint256).max) {
                assertEq(usdglo.allowance(from, sender), approval);
            } else {
                assertEq(usdglo.allowance(from, sender), approval - amount);
            }

            if (from == to) {
                assertEq(usdglo.balanceOf(from), amount);
            } else {
                assertEq(usdglo.balanceOf(from), 0);
                assertEq(usdglo.balanceOf(to), amount);
            }
        }
    }

    function testBurnInsufficientBalance(uint256 mintAmount, uint256 burnAmount)
        public
    {
        mintAmount = bound(mintAmount, 0, MAX_ALLOWED_SUPPLY);
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        vm.startPrank(minter);

        usdglo.mint(minter, mintAmount);

        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        usdglo.burn(burnAmount);

        vm.stopPrank();
    }

    function testTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        vm.assume(to != address(0));
        mintAmount = bound(mintAmount, 0, MAX_ALLOWED_SUPPLY);
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        vm.prank(minter);
        usdglo.mint(address(this), mintAmount);

        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        usdglo.transfer(to, sendAmount);
    }

    function testTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        approval = bound(approval, 0, MAX_ALLOWED_SUPPLY - 1);
        amount = bound(amount, approval + 1, MAX_ALLOWED_SUPPLY);

        address from = address(0xABCD);

        vm.prank(minter);
        usdglo.mint(from, amount);

        vm.prank(from);
        usdglo.approve(address(this), approval);

        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        usdglo.transferFrom(from, to, amount);
    }

    function testTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        vm.assume(to != address(0));
        mintAmount = bound(mintAmount, 0, MAX_ALLOWED_SUPPLY);
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        vm.prank(minter);
        usdglo.mint(from, mintAmount);

        vm.prank(from);
        usdglo.approve(address(this), sendAmount);

        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        usdglo.transferFrom(from, to, sendAmount);
    }

    function testDenyListInverse(uint256 x) public {
        // set up our mask
        uint256 testMask = uint256(1) << 255;

        // assume our initial balance never surpasses the max allowed supply
        x = bound(x, 0, MAX_ALLOWED_SUPPLY);

        // test if the denylist correctly undoes itself
        uint256 y = x | testMask;
        uint256 z = y & ~testMask;
        assertEq(x, z);
    }

    function testDoubleDenyList(uint256 mintAmount1) public {
        mintAmount1 = bound(mintAmount1, 0, MAX_ALLOWED_SUPPLY);
        uint256 mintAmount2 = MAX_ALLOWED_SUPPLY - mintAmount1;

        // giving address(100) address(200) their mintAmounts
        vm.startPrank(minter);
        usdglo.mint(address(100), mintAmount1);
        usdglo.mint(address(200), mintAmount2);
        vm.stopPrank();

        // denylisting address(100) and destorying their funds
        vm.startPrank(denylister);
        usdglo.denylist(address(100));
        usdglo.destroyDenylistedFunds(address(100));

        // expect all of the supply to be with address(200)
        assertEq(usdglo.balanceOf(address(200)), usdglo.totalSupply());
        assertEq(usdglo.balanceOf(address(200)), mintAmount2);

        // attempt a double denylist (it should revert)
        vm.expectRevert(abi.encodeWithSelector(IsDenylisted.selector, 0x64));
        usdglo.denylist(address(100));

        // undenylist before redenying address(100)
        usdglo.undenylist(address(100));
        usdglo.denylist(address(100));

        // expect 0 usdglo
        assertEq(usdglo.balanceOf(address(100)), 0);

        // see if this impacts supply at all
        usdglo.destroyDenylistedFunds(address(100));
        assertEq(usdglo.balanceOf(address(200)), usdglo.totalSupply());
    }

    function testCanStillPerformActionsWhilePaused(
        uint256 mintAmount1,
        uint256 mintAmount2,
        uint256 mintAmount3
    ) public {
        mintAmount1 = bound(mintAmount1, 0, MAX_ALLOWED_SUPPLY / 4);
        mintAmount2 = bound(mintAmount2, 0, MAX_ALLOWED_SUPPLY / 4);
        mintAmount3 = bound(mintAmount3, 0, MAX_ALLOWED_SUPPLY / 4);
        uint256 mintAmount4 = mintAmount1 + mintAmount2 + mintAmount3;

        // giving address(100) address(200) and the minter their mintAmounts
        vm.startPrank(minter);
        usdglo.mint(address(100), mintAmount1);
        usdglo.mint(address(200), mintAmount2);
        usdglo.mint(minter, mintAmount3);
        vm.stopPrank();

        // pause the contract and check it was paused
        assertEq(usdglo.paused(), false);
        vm.prank(pauser);
        usdglo.pause();
        assertEq(usdglo.paused(), true);

        // giving address(100) mintAmount usdglo (Mint)
        vm.startPrank(minter);
        vm.expectRevert("Pausable: paused");
        usdglo.mint(address(100), mintAmount4);

        // burning minter mintAmount usdglo (Burn)
        vm.expectRevert("Pausable: paused");
        usdglo.burn(mintAmount3);
        vm.stopPrank();

        // sending 100 usdglo to minter (Transfer)
        vm.startPrank(address(100));
        vm.expectRevert("Pausable: paused");
        usdglo.transfer(minter, mintAmount1);

        // setting up approval for transferfrom
        usdglo.approve(address(200), mintAmount1);
        vm.stopPrank();

        // sending 1e6 usdglo to minter (TransferFrom)
        vm.startPrank(address(200));
        vm.expectRevert("Pausable: paused");
        usdglo.transferFrom(address(100), minter, mintAmount1);
        vm.stopPrank();

        // destroying denylist funds !THIS SHOULD WORK!
        vm.startPrank(denylister);
        usdglo.denylist(address(100));
        usdglo.destroyDenylistedFunds(address(100));
    }

    function testCanBalanceOfReturnIncorrectValue(uint256 mintAmount) public {
        mintAmount = bound(mintAmount, 0, MAX_ALLOWED_SUPPLY);

        //mintAmount to address(100)
        vm.prank(minter);
        usdglo.mint(address(100), mintAmount);

        // ensure that the supply is only what has been minted
        assertEq(mintAmount, usdglo.balanceOf(address(100)));

        // check that adding a user to the denylist won't impact their balance returned by balanceOf
        vm.startPrank(denylister);
        usdglo.denylist(address(100));
        assertEq(mintAmount, usdglo.balanceOf(address(100)));

        // check that destroying a user's funds will impact their balance returned by balanceOf
        usdglo.destroyDenylistedFunds(address(100));
        assertEq(0, usdglo.balanceOf(address(100)));
    }

    function testMaxSupplyAtOneAddress(uint256 transferAmount) public {
        transferAmount = bound(transferAmount, 0, MAX_ALLOWED_SUPPLY);

        // mint max allowed supply to address(100)
        vm.prank(minter);
        usdglo.mint(address(100), MAX_ALLOWED_SUPPLY);

        // testing sending to self (Transfer)
        vm.prank(address(100));
        usdglo.transfer(address(100), transferAmount);

        // check that the user is not denylisted and store the balance
        assertEq(usdglo.isDenylisted(address(100)), false);
        uint256 balanceBefore = usdglo.balanceOf(address(100));

        // denylist the user
        vm.prank(denylister);
        usdglo.denylist(address(100));

        // check that the denylist works and that the balance returns the same amount as before
        assertEq(usdglo.isDenylisted(address(100)), true);
        assertEq(usdglo.balanceOf(address(100)), balanceBefore);
    }
}
