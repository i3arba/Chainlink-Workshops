import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

async function deploy() {
  // Deploy do CCIPLocalSimulator
  const localSimulatorFactory = await hre.ethers.getContractFactory(
    "CCIPLocalSimulator"
  );
  const localSimulator = await localSimulatorFactory.deploy();

  // Obter a configuração do Router
  const config: {
    chainSelector_: bigint;
    sourceRouter_: string;
    destinationRouter_: string;
    wrappedNative_: string;
    linkToken_: string;
    ccipBnM_: string;
    ccipLnM_: string;
  } = await localSimulator.configuration();

  // Deploy do CrossChainNameServiceLookup
  const lookupFactory = await hre.ethers.getContractFactory(
    "CrossChainNameServiceLookup"
  );
  const lookup = await lookupFactory.deploy();

  // Deploy do CrossChainNameServiceRegister
  const registerFactory = await hre.ethers.getContractFactory(
    "CrossChainNameServiceRegister"
  );
  const register = await registerFactory.deploy(
    config.sourceRouter_,
    lookup.address
  );

  // Deploy do CrossChainNameServiceReceiver
  const receiverFactory = await hre.ethers.getContractFactory(
    "CrossChainNameServiceReceiver"
  );
  const receiver = await receiverFactory.deploy(
    config.sourceRouter_,
    lookup.address,
    config.chainSelector_
  );

  const chainSelector = config.chainSelector_;

  return { localSimulator, register, receiver, lookup, chainSelector };
}

describe("CrossChainNameService Tests", function () {
  let deployer, alice;
  let localSimulator, register, lookup, chainSelector;
  const gasLimit = 350_000;

  before(async function () {
    [deployer, alice] = await hre.ethers.getSigners();
    ({ localSimulator, register, lookup, chainSelector } = await deploy());
  });

  it("should register and lookup a name correctly", async function () {
    const domain = "alice.ccns";

    await register.enableChain(chainSelector, alice.address, gasLimit);
    await lookup.setCrossChainNameServiceAddress(deployer.address);

    await lookup.register(domain, alice.address);

    const lookupAddress = await lookup.lookup(domain);
    console.log(lookupAddress);
    expect(lookupAddress).to.equal(alice.address);
  });
});
