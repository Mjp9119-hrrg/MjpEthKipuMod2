# MjpEthKipuMod2
Repo de MJP para el TP2(auction) de ETH Kipu
# Auction Smart Contract Documentation

## Overview

The `Auction` contract implements a bidding system for auctions. It is designed for educational purposes only and should not be used in production environments.

## License

- **SPDX-License-Identifier**: GPL-3.0

## Pragma Directive

- Specifies the Solidity compiler version: `pragma solidity >=0.8.2 <0.9.0;`

## Contract Description

### Auction Contract

The contract allows users to place bids, view the current highest bid, and withdraw funds after the auction ends.

### State Variables

- **AUCTION_TIME_TO_LIVE**: Duration of the auction (20 minutes).
- **AUCTION_TIME_EXTENSION**: Extension duration if a bid is placed in the last 10 minutes (10 minutes).
- **PERC_BID_COMMISSION**: Commission percentage deducted from bids (2%).
- **auctionStarted**: Indicates if the auction has started.
- **auctionEnded**: Indicates if the auction has ended.
- **finalRefundPerformed**: Indicates whether the final refund has been executed.
- **auctionDuration**: Timestamp until which the auction is active.
- **currentMaxBid**: Struct holding the highest bidder's address and bid amount.
- **bidList_**: Array to store all bids.
- **_owner**: Address of the contract owner (deployer).
- **userBalance**: Mapping to track each bidder's balance.

### Events

- **NewBid**: Emitted when a new bid is placed.
- **AuctionEnded**: Emitted when the auction is closed.

## Functions

### Constructor

- Initializes the auction duration and sets the owner.

### Fallback Functions

- **receive()**: Accepts incoming Ether.
- **fallback()**: Allows the contract to receive funds with data.

### Bidding

- **newBid()**: 
  - Allows users to place a bid.
  - Updates the current highest bid and user balance.
  - Extends auction duration if the bid is placed in the last 10 minutes.
  - Emits `NewBid` event.

### Auction Management

- **endAuction()**: 
  - Allows the owner to close the auction after its duration has expired.
  - Emits `AuctionEnded` event and triggers final refund.

### Withdrawals

- **withdrawUserBalance()**: 
  - Allows bidders to withdraw their non-winning bids before the auction ends.
  
- **getWithdrawableAmountForAddress(address claimer)**: 
  - Calculates the amount a user can withdraw, excluding their current highest bid.

### Viewing Functions

- **showWinnerBid()**: 
  - Returns the current highest bid after the auction ends.
  
- **showAllBids()**: 
  - Returns the list of all bids.

### Refunds

- **performFinalRefund()**: 
  - Processes refunds for all non-winning bidders after the auction ends.
  - Deducts commission from refunds.

### Owner Functions

- **ownerWithdraw()**: 
  - Allows the owner to withdraw the contract's remaining balance after all refunds are processed.

### Modifiers

- **onlyOwner**: Restricts function access to the contract owner.
- **onlyWhenAuctionHasEnded**: Ensures the function can only be called after the auction ends.
- **onlyWhenFinalRefundPerformed**: Ensures refunds have been processed before executing certain functions.
- **onlyWhenAuctionNotEnded**: Ensures the auction is still active.
- **isValidAmount**: Validates that a new bid exceeds the last bid by at least 5%.
- **whenTimeLeft**: Ensures there is time left for bidding.

### Utility Functions

- **checkMinutesTimeLeft()**: 
  - Returns the remaining auction time in minutes.
  
- **getCurrentMaxBid()**: 
  - Returns the current highest bid details.
  
- **getBalance()**: 
  - Returns the contract's Ether balance.

## Bottom line

This contract provides a basic framework for an auction system, allowing for bidding, withdrawals, and auction management. It should be used for educational purposes only and requires further security and functionality enhancements for production use.
