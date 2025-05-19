// Ported from: https://github.com/Vectorized/solady/blob/main/test/ERC20.t.sol

pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "./Helper.sol";

contract USDGLO_PermitTest is Test, PermitHelpers {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    GloDollarV4 private usdglo;

    address private constant admin = address(1);
    address private constant minter = address(2);

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
    }

    function _expectPermitEmitApproval(_TestTemps memory t) internal {
        vm.expectEmit(true, true, true, true);
        emit Approval(t.owner, t.to, t.amount);
    }

    function _permit(_TestTemps memory t) internal {
        address token_ = address(usdglo);
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(sub(t, 0x20))
            mstore(sub(t, 0x20), 0xd505accf)
            pop(call(gas(), token_, 0, sub(t, 0x04), 0xe4, 0x00, 0x00))
            mstore(sub(t, 0x20), m)
        }
    }

    function _checkAllowanceAndNonce(_TestTemps memory t) internal {
        assertEq(usdglo.allowance(t.owner, t.to), t.amount);
        assertEq(usdglo.nonces(t.owner), t.nonce + 1);
    }

    function _signPermit(_TestTemps memory t) internal view {
        bytes32 innerHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                t.owner,
                t.to,
                t.amount,
                t.nonce,
                t.deadline
            )
        );
        bytes32 domainSeparator = usdglo.DOMAIN_SEPARATOR();
        bytes32 outerHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, innerHash)
        );
        (t.v, t.r, t.s) = vm.sign(t.privateKey, outerHash);
    }

    function testPermit() public {
        _TestTemps memory t = _testTemps();
        t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        _permit(t);

        _checkAllowanceAndNonce(t);
    }

    function testPermit(uint256) public {
        _TestTemps memory t = _testTemps();
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        _permit(t);

        _checkAllowanceAndNonce(t);
    }

    function testPermitBadNonceReverts(uint256) public {
        _TestTemps memory t = _testTemps();
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;
        while (t.nonce == 0) t.nonce = _random();

        _signPermit(t);

        vm.expectRevert("ERC20Permit: invalid signature");
        _permit(t);
    }

    function testPermitBadDeadlineReverts(uint256) public {
        _TestTemps memory t = _testTemps();
        if (t.deadline == type(uint256).max) t.deadline--;
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        vm.expectRevert("ERC20Permit: expired deadline");
        t.deadline += 1;
        _permit(t);
    }

    function testPermitPastDeadlineReverts(uint256) public {
        _TestTemps memory t = _testTemps();
        t.deadline = _bound(t.deadline, 0, block.timestamp - 1);

        _signPermit(t);

        vm.expectRevert("ERC20Permit: expired deadline");
        _permit(t);
    }

    function testPermitReplayReverts(uint256) public {
        _TestTemps memory t = _testTemps();
        if (t.deadline < block.timestamp) t.deadline = block.timestamp;

        _signPermit(t);

        _expectPermitEmitApproval(t);
        _permit(t);
        vm.expectRevert("ERC20Permit: invalid signature");
        _permit(t);
    }
}
