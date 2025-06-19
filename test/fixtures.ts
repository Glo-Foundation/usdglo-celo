import { ethers, upgrades } from "hardhat";
import { PAUSER_ROLE, UPGRADER_ROLE } from "./utils";
const MAX_VERSION = 4;

export function deployUSDGLOFixtureWithVersion(version = MAX_VERSION) {
  async function createFixtures(): Promise<{
    usdglo: any;
    admin: any;
    v3Implementation?: any;
    v4Implementation?: any;
  }> {
    if (version < 0 || version > MAX_VERSION) {
      throw new Error(`Version ${version} of fixture is not supported`);
    }
    const [admin] = await ethers.getSigners();
    const USDGLO_V1 = await ethers.getContractFactory(
      "USDGlobalIncomeCoin",
      admin
    );

    const usdgloV1 = await upgrades.deployProxy(USDGLO_V1, [admin.address], {
      kind: "uups",
    });
    await usdgloV1.deployed();

    await usdgloV1.connect(admin).grantRole(PAUSER_ROLE, admin.address);
    await usdgloV1.connect(admin).pause();

    await usdgloV1.connect(admin).grantRole(UPGRADER_ROLE, admin.address);

    if (version == 1) {
      await usdgloV1.connect(admin).unpause();
      return { usdglo: usdgloV1, admin };
    }

    const USDGLO_V2 = await ethers.getContractFactory(
      "USDGlobalIncomeCoinV2",
      admin
    );

    const usdgloV2 = await upgrades.upgradeProxy(usdgloV1.address, USDGLO_V2, {
      kind: "uups",
    });

    if (version == 2) {
      await usdgloV2.connect(admin).unpause();
      return { usdglo: usdgloV2, admin };
    }

    const USDGLO_V3 = await ethers.getContractFactory("GloDollarV3", admin);

    const v3Implementation = await upgrades.prepareUpgrade(
      usdgloV2.address,
      USDGLO_V3,
      { kind: "uups" }
    );

    await usdgloV2.upgradeToAndCall(
      v3Implementation,
      "0x38e454b100000000000000000000000000000000000000000000000000000000"
    );

    const usdgloV3 = USDGLO_V3.attach(usdgloV2.address);

    if (version == 3) {
      await usdgloV3.connect(admin).unpause();
      return { usdglo: usdgloV3, admin, v3Implementation };
    }

    const USDGLO_V4 = await ethers.getContractFactory("GloDollarV4", admin);

    const v4Implementation = await upgrades.prepareUpgrade(
      usdgloV3.address,
      USDGLO_V4,
      { kind: "uups" }
    );

    await usdgloV3.upgradeTo(v4Implementation.toString());
    const usdglo = USDGLO_V4.attach(usdgloV3.address);

    await usdglo.connect(admin).unpause();
    return { usdglo, admin, v4Implementation };
  }
  return createFixtures;
}

export function deployUSDGLOFixture() {
  return deployUSDGLOFixtureWithVersion(MAX_VERSION)();
}

export async function deployMockUSDGLOFixture() {
  const [admin] = await ethers.getSigners();
  const USDGLO = await ethers.getContractFactory(
    "MockUSDGlobalIncomeCoinV2",
    admin
  );

  const usdglo = await upgrades.deployProxy(USDGLO, [admin.address], {
    kind: "uups",
  });
  await usdglo.deployed();

  return { usdglo, admin };
}
