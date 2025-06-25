// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 ** @title Auction
 ** @dev Implements bidding functionality for an Auction.
 ** @notice This contract is for learning purposes only. DO NOT USE THIS CODE IN A PRODUCTION ENVIRONMENT !!
 */
contract Auction {

    uint16 private constant AUCTION_TIME_TO_LIVE   = 20 minutes; /// Total intended time for the Auction. 
    
    uint16 private constant AUCTION_TIME_EXTENSION = 10 minutes; /// Time for which the auction duration will be extended 

    uint8  private constant PERC_BID_COMMISSION = 2;             /// Percentage to be deducted from each bided amount.

    event NewBid(address indexed id_ , uint256 newBidValue_);   /// Triggers on each new bid.
    event AuctionEnded(string description_);                    /// Triggers when auction is closed.

    bool private auctionStarted;            /// Set to true inside constructor. Starts the Auction period,
    bool private auctionEnded;              /// Defaults to false. Indicates Auction has ended.

    bool private finalRefundPerformed;      /// Flag that indicates whether final refund of non-winning bids has been performed.
 
    uint256 private auctionDuration;        /// Max block.timestamp after which this auction could be closed manually by owner and/or
                                            /// would be closed when someone tries to send a new bid. 


    struct  CurrentMaxBid {                /// Struct to hold max bidder(eventual winner) data 
            address bidder ;     
            uint256 bidAmount;
    }
    CurrentMaxBid private currentMaxBid;   ///  Instance of CurrentMaxBid.


    struct  BidList {                      /// List of pairs: (address, amount) that contains the bidder's address and the amount.
            address bidder_ ;     
            uint256 bidAmount_;
    }
    BidList[] bidList_;                   /// Array instance of BidList. This list will be used in showAllBids.

    address private _owner ;              /// Owner of this contract. It'll be the deployer of this contract. See constructor.

    mapping (address => uint256) internal userBalance ; /// Holds total balance for each individual bidder.


    constructor() {
        
        auctionDuration = block.timestamp + AUCTION_TIME_TO_LIVE ;  /// Set maximum life span for this Auction, starting at instantiation time
        
        auctionStarted = true;            /// Starts the Auction period defined in AUCTION_TIME_TO_LIVE

        _owner = payable(msg.sender);     /// Address of Auction instantiator. Owner and privileged user for this contract.

        // both forms accepted
        //currentMaxBid = CurrentMaxBid({bidder_:msg.sender, bidAmount_:0});
        currentMaxBid = CurrentMaxBid(address(0),0);  // Initializes to zero
    }


    receive() external payable {}     /// Receives ether into this contract.
    
    fallback() external payable {}    /// Fallback in case we receive msg.data.  


    /// Bid
    /** @dev Places a new auction bid, which is also the highest bid up to this point.
    **  Emits NewBid event.
    **  Adds a new position to the bidList array. */ 

    function newBid( ) external payable onlyWhenAuctionNotEnded isValidAmount whenTimeLeft {
       
       /// This struct keeps instant access to winner amount and address.
        currentMaxBid.bidder   = msg.sender;
        currentMaxBid.bidAmount= msg.value ;
      
       /// This map keeps track of individual balances.
       userBalance[msg.sender] += msg.value ;
      
      /// Check to see if this new bid comes in during the last 10 minutes of Auction life.
      if(checkMinutesTimeLeft()<= 10 ){
         
         /// If so, add an extra 10 minute time lapse for the auction.
        auctionDuration += AUCTION_TIME_EXTENSION ; 
      }


    bidList_.push(BidList({bidder_:msg.sender, bidAmount_:msg.value}));  /// Add bidder and amount to the list of bids
 
    emit NewBid(msg.sender,msg.value); /// Emission of required event
    }
    


    /** @dev Used during development. Testing purposes only
     ** @returns uint256 Number of minutes left for the auction  */
    function checkMinutesTimeLeft() public view returns (uint256 ){

        return ( auctionDuration -  block.timestamp )/60; // Returns time left in minutes
    }


    /** @dev Closes the Auction at owner's request ( if time has already expired). 
    **  To be used when time has expired and no more bids are received. */ 

    function endAuction() external onlyOwner{  

        if (block.timestamp > auctionDuration){
        
                auctionEnded = true;   /// Sets the flag for the auction as ended.
        
                emit AuctionEnded("Auction has Closed"); /// Required Close event.
                
                performFinalRefund() ; /// Called at end of auction. Will withdraw all left over funds from contract balance.

        }else{
        
                revert("Time lapse not expired yet !");   /// Just inform there´s time remaining.
        }
    }

    /** @dev Allows bidders to withdraw their previuos non-winning offers at will.
    **  Specified as advanced functionality in the specs */ 
     function withdrawUserBalance() payable external{ 

        /// Always check to see if there's enough balance.
        require(address(this).balance > 0, "Contract wthout funds!!"); 

        /// calculate withdrawable amount for calling user address.
        uint256 withdrawableAmount = getWithdrawableAmountForAddress(msg.sender);

        /// Does NOT deduce comission percentage from withdrawable total at this point.
        /// Deduction not specified for this advanced functionality until auction's end.
        /// Therefore if an user withdraws a non-winning amount prior to Auction end, the deduction is not performed.
        
        // withdraw
        (bool success,) = msg.sender.call{value:withdrawableAmount}("");
        require(success,"Failed to withdraw funds");
        
        // Update user balance 
        userBalance[msg.sender] -= withdrawableAmount ;
        
    }
   
    /** @dev  Calculates the total amount that any bidder can withdraw. Does not deduce commission.
    **  @param  claimer address for wich the calculation is performed.  
    **  @returns withdrawableAmt Total amount that could be withdrawed by the claimer*/ 
    function getWithdrawableAmountForAddress(address claimer)internal view returns(uint256 ){
     
      /// Balance of claimer address.
      uint256  withdrawableAmt = userBalance[claimer];
      
      /// Check if Auction's current max bid belongs to same address. If so, subtract this amt. from withdrawable total.
      if(currentMaxBid.bidder == claimer){              

        withdrawableAmt -= currentMaxBid.bidAmount ;
      }

     return(withdrawableAmt);
    }


    /** @dev Used to restrict "manually" closing of the Auction only to contract owner.
    **  @notice  there's another way by which the auction is ended. It occurs when someone 
    **  tries to perform a new bid and time lapse is over */
  
    modifier onlyOwner {

        require(msg.sender == _owner,"Not authorized."); 
        _;
    }

   
    /** @dev Shows the bid that wins the Auction
    ** only if auction has already ended    
    ** @return currentMaxBid tuple of winner-address and bid amount */
    function showWinnerBid()external view onlyWhenAuctionHasEnded returns (CurrentMaxBid memory ){ 
        
        return(currentMaxBid); /// Show the bid resulting to be the winner after auction finished.
    }

    /** @dev Shows the list of bidings only if auction has already ended
    ** @returns bidList_ array of bids  */

    function showAllBids() external view returns( BidList[] memory ){ 
        
        return (bidList_);
    }


    /** @dev Performs the refund of all non winning and remaining balances for every participant
    ** Sets performedFinalRefund to true.
    ** Deduces comission prior to refunding balances.
    ** Called when Auction is declared ended by owner (from within endAuction function ) or 
    ** en case of error that may have left pending bidder's balances, it could be called "manually" by owner . */
    function performFinalRefund() public payable  onlyWhenAuctionHasEnded onlyOwner{
   
        /// Check if there's enough balance.
        require(address(this).balance > 0, "Contract has no funds!!"); 
        
        uint256 len     = bidList_.length; /// length of array bidList_
        uint256 i       = 0;               /// for loop counter 
        address toRefundAddress ;          /// address to which funds will be sent
        uint256 withdrawableAmt = 0;       /// amount to be sent to toRefundAddress

        /// Iterate list of bids, hoping they're not too many!!
        for (;i<len ; i++){
            
            toRefundAddress = bidList_[i].bidder_;  /// get possible address to refund

            if( userBalance[toRefundAddress] > 0 ){ /// address has a balance, then try to refund.

                withdrawableAmt = getWithdrawableAmountForAddress( toRefundAddress );
                
                /// Deduce commission as this is final refund.
                withdrawableAmt -= (withdrawableAmt * PERC_BID_COMMISSION / 100); 

                /// Send balance for current address
                (bool success,) = toRefundAddress.call{value:withdrawableAmt}("");
                require(success,"Failed to perform final refund.");
        
                /// Update current address balance to zero so that in case of a particular 
                ///  refund fails that would left a non-zero balance allowing the owner to re-try refund pending balances (balances > 0) 
                /// At the same time the originalk list of bids (bidList_) remains unmodified and retrievable at any moment.
                userBalance[toRefundAddress] = 0;

            }
        }

        /// Set flag to indicate final refund of non winning bids has been performed. 
        finalRefundPerformed = true ;
    }      


    /* @dev Final withdraw of any contract balance and send it to the owner.
    ** Externally called by owner*/
    function ownerWithdaw()external payable onlyWhenAuctionHasEnded onlyWhenFinalRefundPerformed onlyOwner{

        require(address(this).balance >0 , "Contract without a balance!");

        (bool success, ) = _owner.call{value:address(this).balance}( ""); 
        require(success,"Failed to withdraw balance!");
    }
    
    
    /* @dev Verify that there are no pending non-winner funds for this contract balance 
    ** */
    modifier onlyWhenFinalRefundPerformed(){

        require(finalRefundPerformed, "Final refund not performed yet");
        _;  
    }

    /* @dev Checks the ended flag state 
    ***/
    modifier onlyWhenAuctionHasEnded(){ 

        require(auctionEnded, "Auction NOT over yet!!");
        _;   
    }   

    /** @dev Checks and/or Sets the auctionended flag    */
    modifier onlyWhenAuctionNotEnded() {

        /// Here the auctionEnded flag is set to true by any user if auction time is over at the time of trying a new bid.
        /// The endAuction func. in contrast, is only accesible by the contract owner and Closes the auction 
        /// when time has expired and there are no more bids.
        /// The endAuction function also performs final refund.

        if (block.timestamp > auctionDuration) auctionEnded = true;

        require(!auctionEnded, "Auction is over!");

        _;
    }


    /** @dev check new amount exceeds by 5% last higher amount  */

    modifier isValidAmount() {

        uint256 currentHigh = currentMaxBid.bidAmount;

        require(
                msg.value > (((currentHigh * 5) / 100) + currentHigh),
                "Last bid must be exceeded by 5%"  
        );
        
        _;
    }

    /* @dev Checks to see if there's still time left for this Auction */
    modifier whenTimeLeft() {
    
      require( checkMinutesTimeLeft()>0,"No time lef to for bidding");
      _;
    }
   
    /* @returns currentMaxBid  */
    function getCurrentMaxBid() external view returns (CurrentMaxBid memory ) {

        return currentMaxBid;
    }
     
      function getBalance() public view returns (uint256) {

        return address(this).balance;
    }
}
