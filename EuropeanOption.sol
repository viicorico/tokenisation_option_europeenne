// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract EuropeanOption is ERC721URIStorage
{
    uint256 public constant OPTION_ID = 1;
    
    enum OptionType {CALL, PUT}
    OptionType public optionType;
    
    address payable public issuer;

    uint public premium;
    uint public strikePrice;
    uint public price;

    uint public maturity;
    bool public isActive;
    bool public priceFinalized;
    bool public minted;

    event Bought(address indexed buyer, uint premium);
    event PriceSet(uint price);
    event Exercised(address indexed buyer, uint payout);
    event Expired();
    event CollateralFunded(address indexed by, uint amount);

    constructor(uint _premium, uint _strikePrice, uint _maturity, OptionType _optionType) ERC721("EuropeanOption", "EOPT") payable {
        require(_maturity > block.timestamp, "Bad maturity");
        require(msg.value > 0, "Premium must be sent" );

        premium = _premium;
        issuer = payable(msg.sender);
        strikePrice = _strikePrice;
        maturity = _maturity;
        premium = msg.value;
        optionType = _optionType;
        isActive = true;        
    } 

 // modifier

    modifier onlyHolder() {
        require (msg.sender == ownerOf(OPTION_ID), "Only holder can exercise");
        _;
    }

    modifier onlyIssuer() {
        require (msg.sender == issuer);
        _;
    }

    modifier afterMaturity() {
        require(block.timestamp >= maturity, "Wait for maturity");
        _;
    }

    modifier onlyIfNotBought() {
        require(!minted, "Option already bought");
        _;
    }

    modifier onlyIfActive() {
        require(isActive, "Option is not active");
        _;
    }
    
// functions

    function _inTheMoney() internal view returns (bool) {
        if (optionType == OptionType.CALL) {
            return strikePrice < price;
        } else {
            return strikePrice > price;
        }
    }

    function getPayout() internal view returns (uint) {
        if (optionType == OptionType.CALL) {
            if (price > strikePrice) {
                return price - strikePrice;
            } else {
                return 0;
            }
        } else { // PUT
            if (strikePrice > price) {
                return strikePrice - price;
            } else {
                return 0;
            }
        }
    }

    function setPrice(uint _price) external onlyIssuer afterMaturity {
        require(!priceFinalized, "Price already set");
        price = _price;
        priceFinalized = true;
        emit PriceSet(_price);
    }

    function buy() external payable onlyIfActive onlyIfNotBought {
        require(!minted, "Already bought");
        require(block.timestamp < maturity, "Too late to buy");
        require(msg.value == premium, "Send exact premium");
        minted = true;
        _mint(msg.sender, OPTION_ID);
        issuer.transfer(msg.value); 
        emit Bought(msg.sender, msg.value);

    }

     function exercise() external onlyHolder afterMaturity onlyIfActive {
        require(priceFinalized, "Price not set");
        uint payout = getPayout();
        require(payout > 0, "Out of the money");
        require(address(this).balance >= payout, "Insufficient collateral");
        isActive = false;
        _burn(OPTION_ID);
        payable(msg.sender).transfer(payout);
        emit Exercised(msg.sender, payout);
        
    }

   
    // fallback pour recevoir fonds
    function fundCollateral() external payable onlyIssuer {
        require(msg.value > 0, "Zero amount");
        emit CollateralFunded(msg.sender, msg.value);
    }

    function expire() external afterMaturity onlyIfActive {
        uint payout = getPayout();
        require(payout == 0, "In the money");
        isActive = false;
        emit Expired();
    }

    function withdrawCollateral(uint amount) external onlyIssuer {
        require(!isActive, "Option still active");
        require(amount <= address(this).balance, "Too much");
        issuer.transfer(amount);
    }

    receive() external payable {
        emit CollateralFunded(msg.sender, msg.value);
    }
}  
