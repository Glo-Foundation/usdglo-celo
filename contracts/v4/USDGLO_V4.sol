// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../v2/ERC20Upgradeable_V2.sol";
import "../v3/ERC20PermitUpgradeable_V3.sol";
import "./CalledByVm.sol";

/// @custom:security-contact Garm Lucassen <garm@glodollar.org>
contract GloDollarV4 is
    Initializable,
    ERC20UpgradeableV2,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ERC20PermitUpgradeableV3,
    CalledByVm
{
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DENYLISTER_ROLE = keccak256("DENYLISTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __ERC20_init("Glo Dollar", "USDGLO");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Not needed?
    // https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable
    function initializeV4() public reinitializer(3) {
        __ERC20Permit_init("Glo Dollar");
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function denylist(address denylistee) external onlyRole(DENYLISTER_ROLE) {
        _denylist(denylistee);
    }

    function undenylist(address denylistee) external onlyRole(DENYLISTER_ROLE) {
        _undenylist(denylistee);
    }

    function destroyDenylistedFunds(address denylistee)
        external
        onlyRole(DENYLISTER_ROLE)
    {
        _destroyDenylistedFunds(denylistee);
    }

    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotDenylisted(_msgSender())
    {
        _mint(to, amount);
        emit Mint({minter: _msgSender(), to: to, amount: amount});
    }

    function burn(uint256 amount) external onlyRole(MINTER_ROLE) {
        _burn(_msgSender(), amount);
        emit Burn({burner: _msgSender(), amount: amount});
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    /**
     * @notice Reserve balance for making payments for gas in this StableToken currency.
     * @param from The account to reserve balance from
     * @param value The amount of balance to reserve
     * @dev Note that this function is called by the protocol when paying for tx fees in this
     * currency. After the tx is executed, gas is refunded to the sender and credited to the
     * various tx fee recipients via a call to `creditGasFees`.
     */
    function debitGasFees(address from, uint256 value) external onlyVm {
        _burn(from, value);
    }

    /**
     * @notice Alternative function to credit balance after making payments
     * for gas in this StableToken currency.
     * @param from The account to debit balance from
     * @param feeRecipient Coinbase address
     * @param gatewayFeeRecipient Gateway address
     * @param communityFund Community fund address
     * @param refund amount to be refunded by the VM
     * @param tipTxFee Coinbase fee
     * @param baseTxFee Community fund fee
     * @param gatewayFee Gateway fee
     * @dev Note that this function is called by the protocol when paying for tx fees in this
     * currency. Before the tx is executed, gas is debited from the sender via a call to
     * `debitGasFees`.
     */
    function creditGasFees(
        address from,
        address feeRecipient,
        address gatewayFeeRecipient,
        address communityFund,
        uint256 refund,
        uint256 tipTxFee,
        uint256 gatewayFee,
        uint256 baseTxFee
    ) external onlyVm {
        // slither-disable-next-line uninitialized-local
        uint256 amountToBurn;
        _mint(from, refund + tipTxFee + gatewayFee + baseTxFee);

        if (feeRecipient != address(0)) {
            _transfer(from, feeRecipient, tipTxFee);
        } else if (tipTxFee > 0) {
            amountToBurn += tipTxFee;
        }

        if (gatewayFeeRecipient != address(0)) {
            _transfer(from, gatewayFeeRecipient, gatewayFee);
        } else if (gatewayFee > 0) {
            amountToBurn += gatewayFee;
        }

        if (communityFund != address(0)) {
            _transfer(from, communityFund, baseTxFee);
        } else if (baseTxFee > 0) {
            amountToBurn += baseTxFee;
        }

        if (amountToBurn > 0) {
            _burn(from, amountToBurn);
        }
    }
}
