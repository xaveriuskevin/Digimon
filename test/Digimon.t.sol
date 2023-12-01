// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import { Cheats } from "forge-std/Cheats.sol";
import { console } from "forge-std/console.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { Digimon } from "../src/Digimon.sol";

error NotStarted();
error NotAllowed();
error InsufficientValue();
error LimitReached(uint256 minted, uint256 quantity);
error MaxSupplyReached();
error NonExistentTokenURI();
error WithdrawFailed();

// PLEASE: COMMENT the TX.ORIGIN
contract DigimonTest is PRBTest, Cheats {
    using stdStorage for StdStorage;
    Digimon private nft;

    function setUp() public {
        // solhint-disable-previous-line no-empty-blocks
        nft = new Digimon("Digimon", "DMON", "DMON.com/", 5000000000000000, 5, 3333);
    }

    function testCollectionDetails() public {
        string memory name = nft.name();
        assertEq(name, "Digimon");
        string memory symbol = nft.symbol();
        assertEq(symbol, "DMON");
    }

    function testDevMint() public {
        uint256 _qty = 10;
        nft.devMint(_qty);

        vm.startPrank(address(0x3301));
        vm.expectRevert("Ownable: caller is not the owner");
        nft.devMint(_qty);
        vm.stopPrank();
    }

    function testSaleStart() public {
        uint256 _price = 0.005 ether;
        vm.expectRevert(NotStarted.selector);
        nft.mint{ value: _price }(1);

        // success mint
        nft.setSalesStatus(true);
        nft.mint{ value: _price }(1);
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 1);

        // close the sale
        nft.setSalesStatus(false);
        vm.expectRevert(NotStarted.selector);
        nft.mint{ value: _price }(1);
    }

    function testPrice() public {
        uint256 _price = 0.005 ether;
        nft.setSalesStatus(true);

        vm.expectRevert(InsufficientValue.selector);
        nft.mint{ value: _price - 1 }(1);

        // success mint 1
        nft.mint{ value: _price }(1);

        // update the price
        uint256 _updatedPrice = 100000000000000000;
        uint256 _updatedMaxMintAmount = 5;
        nft.setMintDetails(_updatedPrice, _updatedMaxMintAmount);

        vm.expectRevert(InsufficientValue.selector);
        nft.mint{ value: _price }(1);

        // success mint 2
        nft.mint{ value: _updatedPrice }(1);
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, 2);
    }

    function testLimitReached() public {
        uint256 _price = 0.005 ether;
        nft.setSalesStatus(true);

        // success mint 2
        nft.mint{ value: _price }(1);
        nft.mint{ value: _price }(1);

        vm.expectRevert(abi.encodeWithSelector(LimitReached.selector, 2, 4));
        nft.mint{ value: _price * 4 }(4);

        // success mint 2
        nft.mint{ value: _price * 2 }(2);

        vm.expectRevert(abi.encodeWithSelector(LimitReached.selector, 4, 2));
        nft.mint{ value: _price * 2 }(2);

        // success mint 1
        nft.mint{ value: _price }(1);

        vm.expectRevert(abi.encodeWithSelector(LimitReached.selector, 5, 1));
        nft.mint{ value: _price }(1);

        uint256 _updatedPrice = 100000000000000000;
        uint256 _updatedMaxMintAmount = 6;
        nft.setMintDetails(_updatedPrice, _updatedMaxMintAmount);

        // success mint 1
        nft.mint{ value: _updatedPrice }(1);

        vm.expectRevert(abi.encodeWithSelector(LimitReached.selector, 6, 1));
        nft.mint{ value: _updatedPrice }(1);
    }

    function testMaxSupply() public {
        uint256 _price = 0.005 ether;
        uint256 _qty = 3332;
        nft.setSalesStatus(true);

        nft.devMint(_qty);
        uint256 balance = nft.balanceOf(address(this));
        assertEq(balance, _qty);

        (bool success, ) = payable(address(0x3301)).call{ value: 1 ether }("");
        require(success, "WithdrawFailed");
        vm.startPrank(address(0x3301));
        vm.expectRevert(MaxSupplyReached.selector);
        nft.mint{ value: _price }(2);
        //success mint 1 - last item
        nft.mint{ value: _price }(1);
        uint256 balance0x3301 = nft.balanceOf(address(0x3301));
        assertEq(balance0x3301, 1);
        vm.stopPrank();
    }

    function testURI() public {
        uint256 _qty = 10;
        nft.setSalesStatus(true);

        nft.devMint(_qty);
        string memory tokenURI1 = nft.tokenURI(1);
        assertEq("DMON.com/1.json", tokenURI1);
        string memory tokenURI2 = nft.tokenURI(2);
        assertEq("DMON.com/2.json", tokenURI2);
        string memory tokenURI3 = nft.tokenURI(3);
        assertEq("DMON.com/3.json", tokenURI3);
    }

    function testSetURI() public {
        uint256 _qty = 10;
        nft.setSalesStatus(true);
        nft.devMint(_qty);
        string memory tokenURI1 = nft.tokenURI(1);
        assertEq("DMON.com/1.json", tokenURI1);

        vm.startPrank(address(0x3301));
        vm.expectRevert("Ownable: caller is not the owner");
        nft.setBaseURI("ipfs://random/", ".j");
        vm.stopPrank();

        nft.setBaseURI("ipfs://random/", ".json");
        string memory _updatedtokenURI1 = nft.tokenURI(1);
        assertEq("ipfs://random/1.json", _updatedtokenURI1);
    }

    function testWithdrawal() public {
        uint256 _price = 0.005 ether;
        nft.setSalesStatus(true);

        // success mint 1 item
        nft.mint{ value: _price }(1);

        // revert withdrawal as stranger
        vm.startPrank(address(0x3301));
        address _stranger = address(0x3301);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.withdraw(payable(_stranger));
        vm.stopPrank();

        assertEq(address(nft).balance, _price);
        nft.withdraw(payable(address(0xd3ad)));
        assertEq(address(nft).balance, uint256(0));
        assertEq(address(0xd3ad).balance, _price);
    }
}
