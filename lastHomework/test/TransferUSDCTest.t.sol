// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//=== Foundry Tools
import {Test, console, Vm} from "forge-std/Test.sol";
//=== Project Contracts
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {Receiver} from "../src/Receiver.sol";
//=== Chainlink & CCIP Local Imports
import {IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {CCIPLocalSimulator} from "@chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
//=== OpenZeppelin helpers
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TransferUSDCTest is Test {
    //==== Instantiate contracts
    TransferUSDC public transfer;
    Receiver public receiver;
    ERC20Mock public usdc;

    //==== Instantiate CCIP Local
    CCIPLocalSimulator public ccipLocalSimulator;
    MockCCIPRouter public router;

    //==== Common Variables
    uint256 amount = 10*10**18;
    address Barba = makeAddr("Barba");
    uint64 globalChainSelector;

    function setUp() public {
        //=== Deploy contracts
        ccipLocalSimulator = new CCIPLocalSimulator();
        router = new MockCCIPRouter();
        usdc = new ERC20Mock(); //Mock it's from OZ. So, it will have 18 decimals. While real USDC has 6 only.

        (
            uint64 chainSelector,
            ,
            ,
            ,
            LinkToken linkToken,
            ,
            
        ) = ccipLocalSimulator.configuration();

        globalChainSelector = chainSelector;

        transfer = new TransferUSDC(address(router), address(linkToken), address(usdc));
        receiver = new Receiver(address(router));

        //==== Faucet Mint
        ccipLocalSimulator.requestLinkFromFaucet(address(transfer), amount);
        usdc.mint(Barba, amount);
        usdc.mint(address(this), amount);

        //==== Whitelist addresses
        transfer.allowlistDestinationChain(globalChainSelector, true);
        receiver.allowlistSourceChain(globalChainSelector, true);
        receiver.allowlistSender(address(transfer), true);
    }

    function test_transferUSDC() public {
        usdc.approve(address(transfer), amount);

        vm.recordLogs();
        transfer.transferUsdc(
            globalChainSelector,
            address(receiver),
            amount,
            5310
        );
        // Fetches recorded logs to check for specific events and their outcomes.
        Vm.Log[] memory logs = vm.getRecordedLogs();

        console.log(logs.length);

        bytes32 msgExecutedSignature = keccak256(
            "MsgExecuted(bool,bytes,uint256)"
        );

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == msgExecutedSignature) {
                (, , uint256 gasUsed) = abi.decode(
                    logs[i].data,
                    (bool, bytes, uint256)
                );
                console.log(
                    "Gas used: %d",
                    gasUsed
                );
            }
        }

        assertEq(usdc.balanceOf(address(receiver)), amount);
    }
}
