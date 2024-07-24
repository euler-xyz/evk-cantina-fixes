// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {EVaultTestBase} from "./EVaultTestBase.t.sol";
import "../../../src/EVault/shared/types/Types.sol";
import "../../../src/EVault/shared/Constants.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import "forge-std/Console.sol";

contract BorrowBridgeFactory {
    address immutable evc;

    mapping(address vault => mapping(address owner => address bridge)) bridgeLookup;

    constructor (address _evc) {
        evc = _evc;
    }

    function createBridge(address vault, address owner) external returns (address) {
        if (bridgeLookup[vault][owner] == address(0)) {
            bridgeLookup[vault][owner] =
                address(new BorrowBridge{salt: getSalt(vault, owner)}(vault, owner, evc));
        }

        return bridgeLookup[vault][owner];
    }

    function isBridge(address bridge, address vault, address owner) external view returns (bool) {
        return bridgeLookup[vault][owner] == bridge;
    }

    function calculateBridgeAddress(address vault, address owner) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), getSalt(vault, owner), keccak256(abi.encodePacked(type(BorrowBridge).creationCode, abi.encode(vault, owner, evc)))
            )
        );
        return address(uint160(uint256(hash)));
    }

    function getSalt(address vault, address owner) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(vault, owner));
    }
}

contract BorrowBridge {
    address immutable owner;
    address immutable evc;
    address immutable bridgeVault; // the nested vault

    modifier onlyOwner() {
        address sender = msg.sender;
        if (sender == evc) {
            (sender,) = IEVC(evc).getCurrentOnBehalfOfAccount(address(0));
        }

        require(sender == owner, "Unauthorized");
        _;
    }

    constructor(address _bridgeVault, address _owner, address _evc) {
        bridgeVault = _bridgeVault;
        owner = _owner;
        evc = _evc;
        address asset = IEVault(bridgeVault).asset();
        IEVC(evc).enableCollateral(address(this), asset);

        // approve for repays
        IEVault(asset).approve(bridgeVault, type(uint).max);
    }

    function borrow(address vault, uint256 amount) external onlyOwner {
        IEVC(evc).enableController(address(this), vault);
        IEVault(vault).borrow(amount, owner);
    }

    function repay(uint256 amount) external onlyOwner {
        IEVault(bridgeVault).repay(amount, owner);
    }
}

contract BridgeHookTarget {
    address immutable bridgeFactory;

    constructor(address _bridgeFactory) {
        bridgeFactory = _bridgeFactory;
    }

    function isHookTarget() external pure returns (bytes4) {
        return this.isHookTarget.selector;
    }

    function borrow(uint, address receiver) external view {
        address account;
        assembly {
            account := shr(96, calldataload(sub(calldatasize(), 20)))
        }
        require (BorrowBridgeFactory(bridgeFactory).isBridge(receiver, msg.sender, account), "Wrong receiver");
    }
}

contract POC_Test is EVaultTestBase {
    using TypesLib for uint256;

    IEVault eeTST;
    address depositor;
    address borrower;

    TestERC20 assetTARGET;
    IEVault eTARGET;

    address hookTarget;
    address bridgeFactory;

    function setUp() public override {
        // There are 2 vaults deployed with bare minimum configuration:
        // - eTST vault using assetTST as the underlying
        // - eTST2 vault using assetTST2 as the underlying

        // Both vaults use the same MockPriceOracle and unit of account.
        // Both vaults are configured to use IRMTestDefault interest rate model.
        // Both vaults are configured to use 0.2e4 max liquidation discount.
        // Neither price oracles for the assets nor the LTVs are set.
        super.setUp();

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

        // create nested vault
        eeTST = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(eTST), address(oracle), unitOfAccount))
        );

        // TST2 is a long tail collateral
        eeTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);

        bridgeFactory = address(new BorrowBridgeFactory(address(evc)));

        // hook borrow and disable flashloans
        eeTST.setHookConfig(address(new BridgeHookTarget(bridgeFactory)), OP_BORROW | OP_FLASHLOAN);


        // eTST 'borrowing power' will be used to borrow TARGET
        assetTARGET = new TestERC20("Test TARGET", "TARGET", 18, false);
        eTARGET = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTARGET), address(oracle), unitOfAccount))
        );

        eTARGET.setLTV(address(eTST), 0.9e4, 0.9e4, 0);

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTARGET), unitOfAccount, 1e18);
    }

    function test_POC() external {
        // Depositor deposits into eTST and eeTST

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        eTST.approve(address(eeTST), type(uint256).max);
        eeTST.deposit(100e18, depositor);

        // and to eTARGET
        assetTARGET.mint(depositor, type(uint256).max);
        assetTARGET.approve(address(eTARGET), type(uint256).max);
        eTARGET.deposit(100e18, depositor);

        // Borrower deposits into long tail collateral eTST2

        startHoax(borrower);

        assetTST2.mint(borrower, 10e18);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(10e18, borrower);

        evc.enableController(borrower, address(eeTST));
        evc.enableCollateral(borrower, address(eTST2));

        // borrower tries to borrow eTST to a wrong receiver

        vm.expectRevert("Wrong receiver");
        eeTST.borrow(1e18, borrower);

        // borrower has no target asset yet
        assertEq(assetTARGET.balanceOf(borrower), 0);

        // precompute the receiver address
        address receiver = BorrowBridgeFactory(bridgeFactory).calculateBridgeAddress(address(eeTST), borrower);

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3);
        // create bridge if not exists
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: bridgeFactory,
            value: 0,
            data: abi.encodeCall(BorrowBridgeFactory.createBridge, (address(eeTST), borrower))
        });
        // borrow for it
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: address(eeTST),
            value: 0,
            data: abi.encodeCall(eeTST.borrow, (1e18, receiver))
        });
        // use bridge to borrow target asset
        items[2] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: receiver,
            value: 0,
            data: abi.encodeCall(BorrowBridge.borrow, (address(eTARGET), 0.5e18))
        });

        evc.batch(items);

        // borrower got the target asset!
        assertEq(assetTARGET.balanceOf(borrower), 0.5e18);

        // borrower has debt in eeTST
        assertEq(eeTST.debtOf(borrower), 1e18);
        // bridge has debt in eTARGET
        assertEq(eTARGET.debtOf(receiver), 0.5e18);


        // now repay - first TARGET debt, then the bridge debt

        assetTARGET.approve(address(eTARGET), type(uint).max);

        items = new IEVC.BatchItem[](2);

        // repay debt in bridge
        items[0] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: address(eTARGET),
            value: 0,
            data: abi.encodeCall(eTARGET.repay, (type(uint).max, receiver))
        });
        // and now in eeTST
        items[1] = IEVC.BatchItem({
            onBehalfOfAccount: borrower,
            targetContract: receiver,
            value: 0,
            data: abi.encodeCall(BorrowBridge.repay, (type(uint).max))
        });

        evc.batch(items);

        // no debt
        assertEq(eeTST.debtOf(borrower), 0);
        assertEq(eTARGET.debtOf(receiver), 0);

        // withdraw long tail collateral

        eTST2.withdraw(1e18, borrower, borrower);

        assertEq(assetTST2.balanceOf(borrower), 1e18); 
    }
}
