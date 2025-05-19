pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "./Helper.sol";
import "./USDGLOHandler.sol";
import "forge-std/StdInvariant.sol";

contract USDGLO_Test is Test {
    GloDollarV4 private usdglo;
    USDGloHandler private usdgHandler;

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

        usdgHandler = new USDGloHandler(usdglo);

        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = usdgHandler.transfer.selector;
        selectors[1] = usdgHandler.approve.selector;
        selectors[2] = usdgHandler.increaseAllowance.selector;
        selectors[3] = usdgHandler.decreaseAllowance.selector;
        selectors[4] = usdgHandler.transferFrom.selector;
        selectors[5] = usdgHandler.burn.selector;
        selectors[6] = usdgHandler.mint.selector;
        selectors[7] = usdgHandler.pause.selector;
        selectors[8] = usdgHandler.unpause.selector;
        selectors[9] = usdgHandler.denylist.selector;
        selectors[10] = usdgHandler.undenylist.selector;
        selectors[11] = usdgHandler.destroyDenylistedFunds.selector;

        targetSelector(
            FuzzSelector({addr: address(usdgHandler), selectors: selectors})
        );

        targetContract(address(usdgHandler));

        vm.prank(minter);
        usdglo.mint(address(usdgHandler), MAX_ALLOWED_SUPPLY);
    }

    function invariant_sumOfBalancesIsAlwaysTotalSupply() public {
        address[] memory actors = usdgHandler.actors();
        uint256 actorsLen = actors.length;

        uint256 sumOfBalances;

        for (uint256 i; i < actorsLen; ++i) {
            sumOfBalances = sumOfBalances + usdglo.balanceOf(actors[i]);
        }

        assertEq(sumOfBalances, usdglo.totalSupply());
    }

    function invariant_sumOfBalancesIsNeverMoreThanMaxAllowed() public {
        address[] memory actors = usdgHandler.actors();
        uint256 actorsLen = actors.length;

        uint256 sumOfBalances;

        for (uint256 i; i < actorsLen; ++i) {
            sumOfBalances = sumOfBalances + usdglo.balanceOf(actors[i]);
        }

        assertLe(sumOfBalances, MAX_ALLOWED_SUPPLY);
    }
}
