import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { deployUSDGLOFixture } from "./fixtures";
import { ethers, upgrades } from "hardhat";

import {
  getAccessControlRevertMessage,
  UPGRADER_ROLE_NAME,
  UPGRADER_ROLE,
  PAUSER_ROLE,
} from "./utils";

describe("upgradeable functionality of USDGLO", function () {
  describe("role behaviour", function () {
    it("reverts upgrade if called by address without UPGRADER_ROLE", async function () {
      const [admin, user] = await ethers.getSigners();
      const USDGLO_V1 = await ethers.getContractFactory(
        "USDGlobalIncomeCoin",
        admin
      );

      const usdgloV1 = await upgrades.deployProxy(USDGLO_V1, [admin.address], {
        kind: "uups",
      });
      await usdgloV1.deployed();

      const USDGLOV2 = await ethers.getContractFactory(
        "USDGlobalIncomeCoinV2",
        user
      );

      const expectedRevertMessage = getAccessControlRevertMessage(
        UPGRADER_ROLE_NAME,
        user.address
      );

      await expect(
        upgrades.upgradeProxy(usdgloV1, USDGLOV2, { kind: "uups" })
      ).to.be.revertedWith(expectedRevertMessage);
    });

    it("successful upgrade if called by address with UPGRADER_ROLE", async function () {
      const [admin, user] = await ethers.getSigners();
      const USDGLO_V1 = await ethers.getContractFactory(
        "USDGlobalIncomeCoin",
        admin
      );

      const usdgloV1 = await upgrades.deployProxy(USDGLO_V1, [admin.address], {
        kind: "uups",
      });
      await usdgloV1.deployed();

      const USDGLOV2 = await ethers.getContractFactory(
        "USDGlobalIncomeCoinV2",
        user
      );
      const USDGLOV3 = await ethers.getContractFactory("GloDollarV3", user);
      const USDGLOV4 = await ethers.getContractFactory("GloDollarV4", user);

      await usdgloV1.connect(admin).grantRole(UPGRADER_ROLE, user.address);

      const usdgloV2 = await upgrades.upgradeProxy(usdgloV1, USDGLOV2, {
        kind: "uups",
      });
      const usdgloV3 = await upgrades.upgradeProxy(usdgloV2, USDGLOV3, {
        kind: "uups",
        call: {
          fn: "initializeV3",
          args: [],
        },
      });
      await upgrades.upgradeProxy(usdgloV3, USDGLOV4, {
        kind: "uups",
      });
    });

    it("successful upgrade if called by address with UPGRADER_ROLE - 2", async function () {
      const [admin] = await ethers.getSigners();
      const USDGLO_V1 = await ethers.getContractFactory(
        "USDGlobalIncomeCoin",
        admin
      );

      const usdgloV1 = await upgrades.deployProxy(USDGLO_V1, [admin.address], {
        kind: "uups",
      });
      await usdgloV1.deployed();

      expect(await usdgloV1.paused()).to.be.false;
      await usdgloV1.connect(admin).grantRole(PAUSER_ROLE, admin.address);
      await usdgloV1.connect(admin).pause();
      expect(await usdgloV1.paused()).to.be.true;

      await usdgloV1.connect(admin).grantRole(UPGRADER_ROLE, admin.address);

      const USDGLOV2 = await ethers.getContractFactory(
        "USDGlobalIncomeCoinV2",
        admin
      );
      const USDGLOV3 = await ethers.getContractFactory("GloDollarV3", admin);
      const USDGLOV4 = await ethers.getContractFactory("GloDollarV4", admin);

      const usdgloV2 = await upgrades.upgradeProxy(usdgloV1.address, USDGLOV2, {
        kind: "uups",
      });
      const usdgloV3 = await upgrades.upgradeProxy(usdgloV2, USDGLOV3, {
        kind: "uups",
        call: {
          fn: "initializeV3",
          args: [],
        },
      });
      const usdgloV4 = await upgrades.upgradeProxy(usdgloV3, USDGLOV4, {
        kind: "uups",
      });

      expect(await usdgloV4.paused()).to.be.true;
      await usdgloV4.connect(admin).unpause();
      expect(await usdgloV4.paused()).to.be.false;
    });
  });
});
