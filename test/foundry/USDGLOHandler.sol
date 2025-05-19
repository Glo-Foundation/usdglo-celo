pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../../contracts/v4/USDGLO_V4.sol";
import "forge-std/StdCheats.sol";
import "forge-std/StdUtils.sol";
import "./Addresses.sol";

contract USDGloHandler is StdCheats, StdUtils, Test {
    GloDollarV4 public usdglo;

    address private constant admin = address(1);
    address private constant minter = address(2);
    address private constant denylister = address(3);
    address private constant pauser = address(4);

    address private recipientActor;

    using LibAddressSet for AddressSet;

    AddressSet internal _actors;

    constructor(GloDollarV4 _usdglo) {
        usdglo = _usdglo;
        _actors.add(minter);
        _actors.add(denylister);
        _actors.add(pauser);
        _actors.add(address(this));
    }

    /****************************************************
     * Functions from USDGLO used for invariant testing *
     ****************************************************/
    function transfer(uint256 seed, uint256 amount)
        public
        createActor
        useActor(seed)
    {
        amount = bound(amount, 0, usdglo.balanceOf(address(this)));

        vm.startPrank(address(this));
        _sendTokens(msg.sender, amount);
        vm.stopPrank();

        vm.prank(msg.sender);
        usdglo.transfer(recipientActor, amount);
    }

    function increaseAllowance(uint256 seed, uint256 addedValue)
        public
        useActor(seed)
    {
        vm.prank(msg.sender);
        usdglo.increaseAllowance(recipientActor, addedValue);
    }

    function decreaseAllowance(uint256 seed, uint256 subtractedValue)
        public
        useActor(seed)
    {
        subtractedValue = bound(
            subtractedValue,
            0,
            usdglo.balanceOf(msg.sender)
        );
        vm.prank(msg.sender);
        usdglo.decreaseAllowance(recipientActor, subtractedValue);
    }

    function approve(uint256 seed, uint256 amount) public useActor(seed) {
        vm.prank(msg.sender);
        usdglo.approve(recipientActor, amount);
    }

    function transferFrom(
        bool _approve,
        uint256 fromSeed,
        uint256 toSeed,
        uint256 seed,
        uint256 amount
    ) public useActor(seed) {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, usdglo.balanceOf(from));

        if (_approve) {
            vm.prank(from);
            usdglo.approve(recipientActor, amount);
        } else {
            amount = bound(amount, 0, usdglo.allowance(recipientActor, from));
        }

        vm.prank(recipientActor);
        usdglo.transferFrom(from, to, amount);
    }

    function burn(uint256 amount) public {
        vm.prank(minter);
        usdglo.burn(amount);
    }

    function mint(uint256 seed, uint256 amount) public useActor(seed) {
        vm.prank(minter);
        usdglo.mint(recipientActor, amount);
    }

    function pause() public {
        vm.prank(pauser);
        usdglo.pause();
    }

    function unpause() public {
        vm.prank(pauser);
        usdglo.unpause();
    }

    function denylist(address denylistee) public {
        vm.prank(denylister);
        usdglo.denylist(denylistee);
    }

    function undenylist(address denylistee) public {
        vm.prank(denylister);
        usdglo.undenylist(denylistee);
    }

    function destroyDenylistedFunds(uint256 seed) public useActor(seed) {
        vm.prank(denylister);
        usdglo.destroyDenylistedFunds(recipientActor);
    }

    /**********************************
     * helper functions and modifiers *
     **********************************/
    function _sendTokens(address to, uint256 amount) private {
        usdglo.transfer(to, amount);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    modifier createActor() {
        _actors.add(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        recipientActor = _actors.rand(actorIndexSeed);
        _;
    }
}
