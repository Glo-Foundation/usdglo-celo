import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import {
  deployUSDGLOFixture,
  deployUSDGLOFixtureWithVersion,
} from "./fixtures";
import { ethers } from "hardhat";
import {
  readSlot,
  getMappingSlot,
  getNestedMappingSlot,
  parseUInt,
  parseString,
  PAUSER_ROLE,
  DENYLISTER_ROLE,
  MINTER_ROLE,
  getPermitSignature,
} from "./utils";
import { BigNumber, utils } from "ethers";

function checkEmptySlots() {
  it("empty gap from ContextUpgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 1; slot <= 50; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from ERC20Upgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 56; slot <= 100; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from PausableUpgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 102; slot <= 150; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from ERC165Upgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 151; slot <= 200; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from AccessControlUpgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 202; slot <= 250; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from ERC1967UpgradeUpgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 251; slot <= 300; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });

  it("empty gap from UUPSUpgradeable", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    for (let slot = 301; slot <= 350; slot++) {
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    }
  });
}

function checkUnusedSlots() {
  it("bits 17 to 256 of slot 0 is unused", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    const slot = 0;
    const slotValue = await readSlot(usdglo.address, slot);
    const byte32Hex = ethers.utils.hexDataSlice(slotValue, 0, 30);
    expect(parseUInt(byte32Hex)).to.equal(0);
  });

  it("bits 9 to 256 of slot 101 is unused", async function () {
    const { usdglo } = await loadFixture(deployUSDGLOFixture);
    const slot = 0;
    const slotValue = await readSlot(usdglo.address, slot);
    const byte32Hex = ethers.utils.hexDataSlice(slotValue, 0, 31);
    expect(parseUInt(byte32Hex)).to.equal(0);
  });
}

describe("storage slots of USDGLO", function () {
  describe("storage slots of empty gaps", checkEmptySlots);

  describe("storage slots with unused bits ", checkUnusedSlots);

  describe("storage slots of values that can change", function () {
    it("_initialized from Initializable is 1 for V2", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixtureWithVersion(2));
      const slot = 0;
      const slotValue = await readSlot(usdglo.address, slot);
      const byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(1);
    });

    it("_initialized from Initializable is 2 for V3", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixtureWithVersion(3));
      const slot = 0;
      const slotValue = await readSlot(usdglo.address, slot);
      const byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(2);
    });

    it("_initialized from Initializable is 3 for V4", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 0;
      const slotValue = await readSlot(usdglo.address, slot);
      const byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(2);
    });

    it("_initializing from Initializable is false", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 0;
      const slotValue = await readSlot(usdglo.address, slot);
      const byte32Hex = ethers.utils.hexDataSlice(slotValue, 30, 31);
      expect(parseUInt(byte32Hex)).to.equal(0);
    });

    it("_balances mapping", async function () {
      const { usdglo, admin } = await loadFixture(deployUSDGLOFixture);
      const slot = 51;
      await usdglo.connect(admin).grantRole(MINTER_ROLE, admin.address);
      await usdglo.connect(admin).grantRole(DENYLISTER_ROLE, admin.address);

      let slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, admin.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);

      await usdglo.connect(admin).mint(admin.address, 100_000);
      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, admin.address)
      );
      expect(parseUInt(slotValue)).to.equal(100_000);

      await usdglo.connect(admin).burn(50_000);
      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, admin.address)
      );
      expect(parseUInt(slotValue)).to.equal(50_000);

      await usdglo.connect(admin).denylist(admin.address);
      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, admin.address)
      );
      expect(parseUInt(slotValue)).to.equal((1n << 255n) | 50_000n);

      await usdglo.connect(admin).undenylist(admin.address);
      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, admin.address)
      );
      expect(parseUInt(slotValue)).to.equal(50_000);
    });

    it("_allowances mapping", async function () {
      const { usdglo, admin } = await loadFixture(deployUSDGLOFixture);
      const slot = 52;
      const [_, user] = await ethers.getSigners();

      let slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);

      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, admin.address, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);

      await usdglo.connect(admin).approve(user.address, 250_000);
      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, admin.address, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(250_000);

      await usdglo.connect(admin).increaseAllowance(user.address, 25_000);
      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, admin.address, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(275_000);

      await usdglo.connect(admin).decreaseAllowance(user.address, 250_000);
      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, admin.address, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(25_000);
    });

    it("0 _totalSupply", async function () {
      const { usdglo, admin } = await loadFixture(deployUSDGLOFixture);
      const slot = 53;
      await usdglo.connect(admin).grantRole(MINTER_ROLE, admin.address);

      let slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);

      await usdglo.connect(admin).mint(admin.address, 100_000);
      slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(100_000);

      await usdglo.connect(admin).burn(50_000);
      slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(50_000);
    });

    it("_name", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 54;
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseString(slotValue)).to.equal("Glo Dollar");
    });

    it("_symbol", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 55;
      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseString(slotValue)).to.equal("USDGLO");
    });

    it("_paused from PausableUpgradeable", async function () {
      const { usdglo, admin } = await loadFixture(deployUSDGLOFixture);
      const slot = 101;
      await usdglo.connect(admin).grantRole(PAUSER_ROLE, admin.address);

      let slotValue = await readSlot(usdglo.address, slot);
      let byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(0);

      await usdglo.connect(admin).pause();
      slotValue = await readSlot(usdglo.address, slot);
      byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(1);

      await usdglo.connect(admin).unpause();
      slotValue = await readSlot(usdglo.address, slot);
      byte32Hex = ethers.utils.hexDataSlice(slotValue, 31, 32);
      expect(parseUInt(byte32Hex)).to.equal(0);
    });

    it("_roles mapping", async function () {
      const { usdglo, admin } = await loadFixture(deployUSDGLOFixture);
      const slot = 201;
      const [_, user] = await ethers.getSigners();

      let slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);

      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, MINTER_ROLE, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);

      await usdglo.connect(admin).grantRole(MINTER_ROLE, user.address);
      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, MINTER_ROLE, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(1);

      await usdglo.connect(admin).revokeRole(MINTER_ROLE, user.address);
      slotValue = await readSlot(
        usdglo.address,
        getNestedMappingSlot(usdglo.address, slot, MINTER_ROLE, user.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);
    });

    it("_HASHED_NAME", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 351;

      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(
        utils.keccak256(utils.toUtf8Bytes("Glo Dollar"))
      );
    });

    it("_HASHED_VERSION", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 352;

      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(
        utils.keccak256(utils.toUtf8Bytes("1"))
      );
    });

    it("_nonces mapping", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const [_, user1, user2, user3] = await ethers.getSigners();
      const slot = 403;

      let slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user1.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);

      const {
        v: user1Permit1V,
        r: user1Permit1R,
        s: user1Permit1S,
      } = await getPermitSignature(
        user1,
        usdglo,
        user2.address,
        100_000,
        ethers.constants.MaxInt256
      );
      await usdglo.permit(
        user1.address,
        user2.address,
        100_000,
        ethers.constants.MaxInt256,
        user1Permit1V,
        user1Permit1R,
        user1Permit1S
      );

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user1.address)
      );
      expect(parseUInt(slotValue)).to.equal(1);

      const customDeadline = BigNumber.from(
        (
          await usdglo.signer?.provider?.getBlock(
            await usdglo.signer?.provider?.getBlockNumber()
          )
        )?.timestamp
      ).add(31536000);

      const {
        v: user1Permit2V,
        r: user1Permit2R,
        s: user1Permit2S,
      } = await getPermitSignature(
        user1,
        usdglo,
        user2.address,
        200_000,
        customDeadline
      );
      await usdglo.permit(
        user1.address,
        user2.address,
        200_000,
        customDeadline,
        user1Permit2V,
        user1Permit2R,
        user1Permit2S
      );

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user1.address)
      );
      expect(parseUInt(slotValue)).to.equal(2);

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user2.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);

      const {
        v: user2Permit1V,
        r: user2Permit1R,
        s: user2Permit1S,
      } = await getPermitSignature(
        user2,
        usdglo,
        user1.address,
        1,
        ethers.constants.MaxInt256
      );
      await usdglo.permit(
        user2.address,
        user1.address,
        1,
        ethers.constants.MaxInt256,
        user2Permit1V,
        user2Permit1R,
        user2Permit1S
      );

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user2.address)
      );
      expect(parseUInt(slotValue)).to.equal(1);

      const {
        v: user1Permit3V,
        r: user1Permit3R,
        s: user1Permit3S,
      } = await getPermitSignature(
        user1,
        usdglo,
        user3.address,
        0,
        ethers.constants.MaxInt256
      );
      await usdglo.permit(
        user1.address,
        user3.address,
        0,
        ethers.constants.MaxInt256,
        user1Permit3V,
        user1Permit3R,
        user1Permit3S
      );

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user1.address)
      );
      expect(parseUInt(slotValue)).to.equal(3);

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user2.address)
      );
      expect(parseUInt(slotValue)).to.equal(1);

      slotValue = await readSlot(
        usdglo.address,
        getMappingSlot(usdglo.address, slot, user3.address)
      );
      expect(parseUInt(slotValue)).to.equal(0);
    });

    it("_PERMIT_TYPEHASH_DEPRECATED_SLOT", async function () {
      const { usdglo } = await loadFixture(deployUSDGLOFixture);
      const slot = 404;

      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(0);
    });

    it("Implementation slot v3", async function () {
      const { usdglo, v3Implementation } = await loadFixture(
        deployUSDGLOFixtureWithVersion(3)
      );
      const slot =
        24440054405305269366569402256811496959409073762505157381672968839269610695612n;

      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(v3Implementation);
    });

    it("Implementation slot v4", async function () {
      const { usdglo, v4Implementation } = await loadFixture(
        deployUSDGLOFixture
      );
      const slot =
        24440054405305269366569402256811496959409073762505157381672968839269610695612n;

      const slotValue = await readSlot(usdglo.address, slot);
      expect(parseUInt(slotValue)).to.equal(v4Implementation);
    });
  });
});
