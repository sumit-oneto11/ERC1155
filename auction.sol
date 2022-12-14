// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "IERC1155.sol";
import "IERC20.sol";
import "Ownable.sol";
import "EnumerableMap.sol";

contract AuctionWithAdmin is Ownable {
    // The NFT token we are selling
    IERC1155 private nft_token;
    // The ERC20 token we are using
    IERC20 private token;

    // beneficiary Address
    address beneficiary;

    using EnumerableMap for EnumerableMap.UintToAddressMap;

    // Declare a set state variable
    EnumerableMap.UintToAddressMap private saleId;

    // Declare a set state variable
    EnumerableMap.UintToAddressMap private auctionId;
    // Declare a set state variable
    EnumerableMap.UintToAddressMap private dealId;

    
    struct AuctionDetails {
        // ID of auction
        uint256 id;
        // Price (in token) at beginning of auction
        uint256 price;
        // Time (in seconds) when auction started
        uint256 startTime;
        // Time (in seconds) when auction ended
        uint256 endTime;
        // Address of highest bidder
        address highestBidder;
        // Highest bid amount
        uint256 highestBid;
        // Total number of bids
        uint256 totalBids;
    }

    // Represents an deal on an NFT
    struct DealDetails {
        // Price (in token) at beginning of deal
        uint256 price;
        // Time (in seconds) when deal started
        uint256 startTime;
        // Time (in seconds) when deal ended
        uint256 endTime;
    }

    // Represents an offer on an NFT
    struct OfferDetails {
        // Address of offerer
        address offerer;
        // Price (in token) at beginning of auction
        uint256 uintPrice;        
        // Address of prevOfferer
        uint256 quantity;
        // Time (in seconds) when offer created
        uint256 time;
    }
    
    // Represents an Bid on Auction NFT
    struct BidDetails {
        // Address of next bidder
        address nextBidder;
        // Address of prev bidder
        address prevBidder;
        // Price (in token) when user place bid
        uint256 amount;
        // Time (in seconds) when bid created
        uint256 time;
    }

    // Mapping token ID to their corresponding auction.
    mapping(uint256 => AuctionDetails) internal auction;
    // Mapping token ID to their corresponding deal.
    mapping(uint256 => DealDetails) internal deal;
    // Mapping token ID to their corresponding offer.
    mapping(uint256 => mapping(uint256 => OfferDetails)) internal offer;
    // Mapping from addresss to token ID for claim.
    mapping(address => mapping(uint256 => uint256)) internal pending_claim_offer;
    // Mapping from addresss to token ID for claim.
    mapping(address => mapping(uint256 => uint256)) internal pending_claim_auction;
    // Mapping from address to token ID for bid
    mapping(address => mapping(uint256 => BidDetails)) public bid_info;
    // Mapping from address to token ID for bid
    mapping(address => mapping(uint256 => OfferDetails)) public offer_info;
    // Mapping from sale ID to token price
    mapping(uint256 => uint256) internal token_price;
    // Mapping from token ID to sale ID
    mapping(IERC1155 => mapping(uint256 => uint256)) internal tokenIdToSaleId;
    

    mapping(address => mapping(IERC1155 => uint256[])) internal saleTokenIds;
    mapping(uint256 => uint256) internal saleTokenQuantity;
    mapping(uint256 => uint256) internal totalOffer;
    mapping(address => mapping(IERC1155 => uint256[])) internal auctionTokenIds;
    mapping(address => uint256[]) internal dealTokenIds;

    mapping(uint256 => IERC1155) internal saleIdToNFT;
    mapping(uint256 => uint256) internal saleIdToTokenId;

    mapping(uint256 => IERC1155) internal auctionIdToNFT;
    mapping(uint256 => uint256) internal auctionIdToTokenId;

    uint256 public currentSaleId;
    uint256 public currentAuctionId;
    uint256 public currentDealId;

    uint256 public sell_token_fee;
    uint256 public auction_token_fee;
    uint256 internal cancel_bid_fee;
    uint256 internal cancel_offer_fee;

    bool internal sell_service_fee = false;
    bool internal auction_service_fee = false;
    bool internal cancel_bid_enable = false;
    bool internal cancel_offer_enable = false;
    

    event SellFee(
        uint256 indexed _id,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _time
    );
    event AuctionFee(
        uint256 indexed _id,
        uint256 _tokenId,
        uint256 _fee,
        uint256 _time
    );
    event Sell(
        uint256 indexed _id,
        address indexed _seller,
        IERC1155 _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _quantity,
        uint256 _time
    );
    event SellCancelled(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event Buy(
        uint256 indexed _id,
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _quantity,
        uint256 _time
    );
    event AuctionCreated(
        uint256 indexed _id,
        address indexed _seller,
        IERC1155 _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    );
    event Bid(
        uint256 indexed _id,
        address indexed _bidder,
        uint256 indexed _tokenId,
        uint256 _price,
        uint256 _time
    );
    event AuctionCancelled(
        uint256 indexed _id,
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event BidCancelled(
        address indexed _bidder,
        uint256 indexed _auctionId,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _time
    );
    event OfferCancelled(
        address indexed _offerer,
        uint256 _saleId,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _time
    );
    event DealCreated(
        address indexed _seller,
        uint256 _tokenId,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    );
    event BuyDeal(
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _time
    );
    event DealCancelled(
        address indexed _seller,
        uint256 _tokenId,
        uint256 _time
    );
    event OfferMaked(
        uint256  indexed _saleId,
        uint256  indexed _offerId,
        address  indexed _offerer,
        IERC1155 _NFT,
        uint256  _tokenId,
        uint256  _price, 
        uint256  _quantity,
        uint256  _time
    );
    event OfferReceived(
        uint256 indexed _saleId,
        address indexed _buyer,
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _time
    );
    event AuctionClaimed(
        uint256 indexed _id,
        address indexed _buyer,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );
    event OfferClaimed(
        address indexed _buyer,
        uint256 indexed _saleId,
        uint256 _tokenId,
        uint256 _price,
        uint256 _time
    );


    /// @dev Initialize the nft token contract address.
    /// @param _nftToken - NFT token addess.
    /// @param _token    - ERC20 token addess.
    function initialize(address _nftToken, address _token)
        public
        virtual
        onlyOwner
        returns (bool)
    {
        require(_nftToken != address(0));
        nft_token = IERC1155(_nftToken);
        token = IERC20(_token);
        return true;
    }

    /// @dev Set the beneficiary address.
    /// @param _owner - beneficiary addess.
    function setBeneficiary(address _owner) public onlyOwner {
        beneficiary = _owner;
    }

    /// @dev Contract owner set the token fee percent which is for sell.
    /// @param _tokenFee - Token fee.
    function setTokenFeePercentForSell(uint256 _tokenFee) public onlyOwner {
        sell_token_fee = _tokenFee;
    }

    /// @dev Contract owner set the token fee percent which is for auction.
    /// @param _tokenFee - Token fee.
    function setTokenFeePercentForAuction(uint256 _tokenFee) public onlyOwner {
        auction_token_fee = _tokenFee;
    }

    /// @dev Contract owner set the cancelbid fee percent.
    /// @param _tokenFee - Token fee.
    function setCancelBidFee(uint256 _tokenFee) public onlyOwner {
        cancel_bid_fee = _tokenFee;
    }

    /// @dev Contract owner set the canceloffer fee percent.
    /// @param _tokenFee - Token fee.
    function setCancelOfferFee(uint256 _tokenFee) public onlyOwner {
        cancel_offer_fee = _tokenFee;
    }

    /// @dev Contract owner enables and disable the sell token service fee.
    function sellServiceFee() public onlyOwner {
        sell_service_fee = !sell_service_fee;
    }

    /// @dev Contract owner enables and disable the auction token service fee.
    function auctionServiceFee() public onlyOwner {
        auction_service_fee = !auction_service_fee;
    }

    /// @dev Contract owner enables and disable the cancel bid.
    function cancelBidEnable() public onlyOwner{
        cancel_bid_enable = !cancel_bid_enable;
    }

    /// @dev Contract owner enables and disable the cancel offer.
    function cancelOfferEnable() public onlyOwner{
        cancel_offer_enable = !cancel_offer_enable;
    }


        /// @dev Creates and begins a new deal.
    /// @param _tokenId - ID of token to deal, sender must be owner.
    /// @param _price - Price of token (in token) at deal.
    /// @param _startTime - Start time of deal.
    /// @param _endTime - End time of deal.
    function createDeal(
        uint256 _tokenId, 
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner{
        require(nft_token.balanceOf(msg.sender,_tokenId)>0, "Only owner");
        require(
            nft_token.isApprovedForAll(msg.sender,address(this)),
            "Token not approved"
        );
        require(
            _startTime < _endTime && _endTime > block.timestamp,
            "Check Time"
        );
        require(
            _price > 0,
            "Price must be greater than zero"
        );

        DealDetails memory dealToken;
        dealToken = DealDetails({
            price: _price,
            startTime: _startTime,
            endTime: _endTime
        });
        currentDealId++;
        deal[_tokenId] = dealToken;
        dealTokenIds[msg.sender].push(_tokenId);
        EnumerableMap.set(dealId, _tokenId, msg.sender);
        nft_token.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");       
        emit DealCreated(msg.sender, _tokenId, _price, _startTime, _endTime);
    }

    /// @dev Buy from open sell.
    /// Transfer NFT ownership to buyer address.
    /// @param _tokenId - ID of NFT on buy.
    /// @param _amount  - Seller set the price (in token) of NFT token.
    function buyDeal(uint256 _tokenId, uint256 _amount) public {        
        require(
            block.timestamp > deal[_tokenId].startTime,
            "Deal not started yet"
        );
        require(block.timestamp < deal[_tokenId].endTime, "Deal is over");
        require(
            EnumerableMap.get(dealId, _tokenId)!= address(0) && deal[_tokenId].price > 0,
            "Token not for deal"
        );
        require(msg.sender != EnumerableMap.get(dealId, _tokenId), "Owner can't buy");
        require(_amount >= deal[_tokenId].price, "Your amount is less");
        nft_token.safeTransferFrom(address(this), msg.sender, _tokenId,1,"");
        token.transferFrom(
            msg.sender,
            EnumerableMap.get(dealId, _tokenId),
            _amount
        ); 
        emit BuyDeal(
            msg.sender,
            _tokenId,
            EnumerableMap.get(dealId, _tokenId),
            _amount,
            block.timestamp
        );
        delete deal[_tokenId];
        for(uint256 i = 0; i < dealTokenIds[msg.sender].length; i++){
            if(dealTokenIds[msg.sender][i] == _tokenId){
                dealTokenIds[msg.sender][i] = dealTokenIds[msg.sender][dealTokenIds[msg.sender].length-1];
                delete dealTokenIds[msg.sender][dealTokenIds[msg.sender].length-1];
                break;
            }
        }
        EnumerableMap.remove(dealId, _tokenId);
    }

    /// @dev Removes an deal from the list of open deals.
    /// Returns the NFT to original owner.
    /// @param _tokenId - ID of NFT on deal.
    function cancelDeal(uint256 _tokenId) public onlyOwner {
        require(msg.sender == EnumerableMap.get(dealId, _tokenId) || msg.sender == owner(), "Only owner");
        require(deal[_tokenId].price > 0, "Can't cancel this deal");
        nft_token.safeTransferFrom(address(this), EnumerableMap.get(dealId, _tokenId), _tokenId,1,"");
        currentDealId--;
        delete deal[_tokenId];  
        for(uint256 i = 0; i < dealTokenIds[EnumerableMap.get(dealId, _tokenId)].length; i++){
            if(dealTokenIds[EnumerableMap.get(dealId, _tokenId)][i] == _tokenId){
                dealTokenIds[EnumerableMap.get(dealId, _tokenId)][i] = dealTokenIds[EnumerableMap.get(dealId, _tokenId)][dealTokenIds[EnumerableMap.get(dealId, _tokenId)].length-1];
                delete dealTokenIds[EnumerableMap.get(dealId, _tokenId)][dealTokenIds[EnumerableMap.get(dealId, _tokenId)].length-1];
                break;
            }
        }      
        EnumerableMap.remove(dealId, _tokenId);
        emit DealCancelled(msg.sender, _tokenId, block.timestamp);
    }

    /// @dev Creates and begins a new auction.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _price - Price of token (in token) at beginning of auction.
    /// @param _startTime - Start time of auction.
    /// @param _endTime - End time of auction.
    function createAuction(
        IERC1155 nftToken,
        uint256 _tokenId,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) public {
        require(nftToken.balanceOf(msg.sender,_tokenId)>0, "Only owner");
        require(
            nft_token.isApprovedForAll(msg.sender,address(this)),
            "Token not approved"
        );
        require(
            _startTime < _endTime && _endTime > block.timestamp,
            "Check Time"
        );
        require(
            _price > 0,
            "Invalid price"
        );
        currentAuctionId++;
        AuctionDetails memory auctionToken;
        auctionToken = AuctionDetails({
            id: currentAuctionId,
            price: _price,
            startTime: _startTime,
            endTime: _endTime,
            highestBidder: address(0),
            highestBid: 0,
            totalBids: 0
        });
        
        EnumerableMap.set(auctionId, currentAuctionId, msg.sender);
        auction[currentAuctionId] = auctionToken;
        auctionTokenIds[msg.sender][nftToken].push(_tokenId);
        auctionIdToNFT[currentAuctionId] = nftToken;
        auctionIdToTokenId[currentAuctionId] = _tokenId;
        nftToken.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");
        emit AuctionCreated(currentAuctionId, msg.sender, nftToken, _tokenId, _price, _startTime, _endTime);
    }  

    /// @dev Bids on an open auction.
    /// @param _auctionId - _auctionId of token to bid on.
    /// @param _amount  - Bidder set the bid (in token) of NFT token.
    function bid(uint256 _auctionId, uint256 _amount) public {      
        require(block.timestamp > auction[_auctionId].startTime, "Auction not started yet!");
        require(block.timestamp < auction[_auctionId].endTime, "Auction is over!");
        require(msg.sender != EnumerableMap.get(auctionId, _auctionId), "Owner can't bid in auction!");
        // The first bid, ensure it's >= the reserve price.
        if(_amount < pending_claim_auction[msg.sender][_auctionId]) {
            _amount = pending_claim_auction[msg.sender][_auctionId];
        }
        require(_amount >= auction[_auctionId].price, "Bid must be at least the reserve price!");
        // Bid must be greater than last bid.
        require(_amount > auction[_auctionId].highestBid, "Bid amount too low!");
        token.transferFrom(msg.sender, address(this), _amount - pending_claim_auction[msg.sender][_auctionId]);
       
        if(auction[_auctionId].highestBidder == msg.sender){
            auction[_auctionId].highestBidder = bid_info[msg.sender][_auctionId].prevBidder;
            auction[_auctionId].totalBids--;
        }else{
            if(bid_info[msg.sender][_auctionId].prevBidder == address(0)){
                bid_info[bid_info[msg.sender][_auctionId].nextBidder][_auctionId].prevBidder = address(0);
            }else{
                bid_info[bid_info[msg.sender][_auctionId].prevBidder][_auctionId].nextBidder = bid_info[msg.sender][_auctionId].nextBidder;
                bid_info[bid_info[msg.sender][_auctionId].nextBidder][_auctionId].prevBidder = bid_info[msg.sender][_auctionId].prevBidder;
            }
        }
        delete bid_info[msg.sender][_auctionId];
         
        pending_claim_auction[msg.sender][_auctionId] = _amount;        
        BidDetails memory bidInfo;

        bidInfo = BidDetails({ 
            prevBidder : auction[_auctionId].highestBidder,
            nextBidder : address(0),
            amount     : _amount,
            time       : block.timestamp
        });
        
        if(bid_info[auction[_auctionId].highestBidder][_auctionId].nextBidder == address(0)){
            bid_info[auction[_auctionId].highestBidder][_auctionId].nextBidder = msg.sender;
        }       
        bid_info[msg.sender][_auctionId] = bidInfo;
        pending_claim_auction[msg.sender][_auctionId] = _amount;
        auction[_auctionId].highestBidder = msg.sender;
        auction[_auctionId].highestBid = _amount;
        auction[_auctionId].totalBids++;
        emit Bid(auction[_auctionId].id, msg.sender, _auctionId, _amount, block.timestamp);
    }   

    /// @dev Create claim after auction ends.
    /// Transfer NFT to auction winner address.
    /// Seller and Bidders (not win in auction) Withdraw their funds.
    /// @param _auctionId - ID of auction.

    function auctionClaim(uint256 _auctionId) public {
        IERC1155 nftToken = saleIdToNFT[_auctionId]; 
        uint256 _tokenId = saleIdToTokenId[_auctionId];
        require(auction[_auctionId].endTime < block.timestamp, "auction not compeleted yet");
        require(
            auction[_auctionId].highestBidder == msg.sender || msg.sender == EnumerableMap.get(auctionId, _auctionId) || msg.sender == owner(),
            "You are not highest Bidder or owner"
        );
        
        if(auction_service_fee == true){
            token.transfer(
                beneficiary,
                ((auction[_auctionId].highestBid * auction_token_fee) / 100)
            );
            emit AuctionFee(auction[_auctionId].id, _auctionId, ((auction[_auctionId].highestBid * auction_token_fee) / 100), block.timestamp);
            token.transfer(
                EnumerableMap.get(auctionId, _auctionId),
                ((auction[_auctionId].highestBid * (100 - auction_token_fee)) /
                    100)
            );
        } else {
            token.transfer(EnumerableMap.get(auctionId, _auctionId), auction[_auctionId].highestBid);
        }
        pending_claim_auction[auction[_auctionId].highestBidder][_auctionId] = 0;
        nft_token.safeTransferFrom(address(this), auction[_auctionId].highestBidder, _auctionId, 1, "");          
        emit AuctionClaimed(auction[_auctionId].id, msg.sender, _auctionId, auction[_auctionId].highestBid, block.timestamp);
        for(uint256 i = 0; i < auctionTokenIds[msg.sender][nftToken].length; i++){
            if(auctionTokenIds[msg.sender][nftToken][i] == _tokenId){
                auctionTokenIds[msg.sender][nftToken][i] = auctionTokenIds[msg.sender][nftToken][auctionTokenIds[msg.sender][nftToken].length-1];
                delete auctionTokenIds[msg.sender][nftToken][auctionTokenIds[msg.sender][nftToken].length-1];
                break;
            }
        }
        delete auction[_auctionId];
        EnumerableMap.remove(auctionId, _auctionId);      
    },


    /// @dev Cancel the Offer.
    /// Transfer the offer amount to owner.
    /// @param _tokenId - ID of NFT on sell.
    // function cancelOffer(IERC1155 nftToken, uint256 _tokenId) public {
    //     require(cancel_offer_enable, "You can't cancel the offer");
    //     if(offer[_tokenId].offerer == msg.sender){
    //         offer[_tokenId].offerer = offer_info[msg.sender][_tokenId].prevOfferer;
    //         offer[_tokenId].price   = offer_info[offer_info[msg.sender][_tokenId].prevOfferer][_tokenId].price;
    //     }else{
    //         if(offer_info[msg.sender][_tokenId].prevOfferer == address(0)){
    //             offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = address(0);
    //         }else{
    //             offer_info[offer_info[msg.sender][_tokenId].prevOfferer][_tokenId].offerer = offer_info[msg.sender][_tokenId].offerer;
    //             offer_info[offer_info[msg.sender][_tokenId].offerer][_tokenId].prevOfferer = offer_info[msg.sender][_tokenId].prevOfferer;
    //         }
    //     }
    //     delete offer_info[msg.sender][_tokenId];
    //     emit OfferCancelled(msg.sender, tokenIdToSaleId[nftToken][_tokenId], _tokenId, pending_claim_offer[msg.sender][_tokenId] - (pending_claim_offer[msg.sender][_tokenId] * (cancel_offer_fee / 100)), block.timestamp);
    //     token.transfer(msg.sender, pending_claim_offer[msg.sender][_tokenId] - (pending_claim_offer[msg.sender][_tokenId] * (cancel_offer_fee / 100)));       
    //     pending_claim_offer[msg.sender][_tokenId] = 0;        
    // }

    /// @dev Offer on an sell.
    /// @param sellId - Selll ID of token to offer on.
    /// @param _uintPrice  - Offerer set the price (in token) of NFT token.
    function makeOffer(uint256 sellId, uint256 _uintPrice, uint256 _quantity) public {             
        require(
            EnumerableMap.get(saleId, sellId) != address(0) && token_price[sellId] > 0,
            "Token not for sell"
        );        
        require(msg.sender != EnumerableMap.get(saleId, sellId), "Owner can't make the offer!");
        require(_quantity<=saleTokenQuantity[sellId],"Not enough quantity!");
        require(_uintPrice>0,"Invalid offer price!");
        require(token.transferFrom(msg.sender, address(this), _uintPrice*_quantity),"Token transfer failed!"); 


        totalOffer[sellId]+=1;

        OfferDetails memory offerToken;
        offerToken = OfferDetails({
            offerer:  msg.sender,
            uintPrice:_uintPrice,
            quantity: _quantity,
            time:     block.timestamp
        });
        
        offer[sellId][totalOffer[sellId]]=offerToken;

        emit OfferMaked(sellId, totalOffer[sellId], msg.sender, saleIdToNFT[sellId], saleIdToTokenId[sellId], _uintPrice, _quantity, block.timestamp);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
    }

    /// @dev Receive offer from open sell. 
    /// Transfer NFT ownership to offerer address.
    /// @param sellId - sellId of NFT on offer.
    function receiveOffer(uint256 sellId, uint256 offerId) public {
        IERC1155 nftToken = saleIdToNFT[sellId]; 
        uint256 _tokenId = saleIdToTokenId[sellId];
        require(msg.sender ==  EnumerableMap.get(saleId, sellId), "Only owner");
        nft_token.safeTransferFrom(address(this), offer[sellId][offerId].offerer, _tokenId, offer[sellId][offerId].quantity, "");
        if(sell_service_fee == true){  /* 
            token.transfer(
                beneficiary,
                ((offer[_tokenId].price * sell_token_fee) / 100)
            );
            emit SellFee(
                tokenIdToSaleId[nftToken][_tokenId],
                _tokenId,
                ((offer[_tokenId].price * sell_token_fee) / 100),
                block.timestamp
            );
            token.transfer(
                EnumerableMap.get(saleId, _tokenId),
                ((offer[_tokenId].price * (100 - sell_token_fee)) / 100)
            ); */
        }else{
            token.transfer(
                EnumerableMap.get(saleId, _tokenId),
                offer[sellId][offerId].uintPrice*offer[sellId][offerId].quantity
            );
        }
        
        if((saleTokenQuantity[sellId]-offer[sellId][offerId].quantity)==0)
        {
            EnumerableMap.remove(saleId, _tokenId);
            delete offer_info[offer[sellId][_tokenId].offerer][_tokenId];
            delete offer[sellId][_tokenId];
            delete tokenIdToSaleId[nftToken][_tokenId];   

            for(uint256 i = 0; i < saleTokenIds[msg.sender][nftToken].length; i++){
              if(saleTokenIds[msg.sender][nftToken][i] == _tokenId){
                    saleTokenIds[msg.sender][nftToken][i] = saleTokenIds[msg.sender][nftToken][saleTokenIds[msg.sender][nftToken].length-1];
                    delete saleTokenIds[msg.sender][nftToken][saleTokenIds[msg.sender][nftToken].length-1];
                    break;
                }
            }
            
        }
        else 
        saleTokenQuantity[sellId]=saleTokenQuantity[sellId]-offer[sellId][offerId].quantity;   


        emit OfferReceived(
                tokenIdToSaleId[nftToken][_tokenId],
                offer[sellId][_tokenId].offerer,
                _tokenId,
                msg.sender,
                offer[sellId][_tokenId].uintPrice,
                block.timestamp
            );    
    }

    /// @dev Create claim after offer claim.
    /// Offerers (not win in offer) Withdraw their funds.
    /// @param sellId - sellId of NFT on offer.
    function offerClaim(uint256 sellId, uint256 offerId) public {
        IERC1155 nftToken = saleIdToNFT[sellId]; 
        uint256 _tokenId = saleIdToTokenId[sellId];
        require(offer[sellId][offerId].offerer  != msg.sender, "Your offer is running");
        require(pending_claim_offer[msg.sender][_tokenId] != 0, "You are not a offerer or already claimed");
        token.transfer(msg.sender, pending_claim_offer[msg.sender][_tokenId]);       
        emit OfferClaimed(msg.sender, tokenIdToSaleId[nftToken][_tokenId], _tokenId, pending_claim_offer[msg.sender][_tokenId], block.timestamp);
        delete offer_info[msg.sender][_tokenId];
        pending_claim_offer[msg.sender][_tokenId] = 0;
    }
 

    /// @dev Create claim after auction claim.
    /// bidders (not win in auction) Withdraw their funds.
    /// @param _tokenId - ID of NFT.
    function auctionPendingClaim(uint256 _tokenId) public {
        require(auction[_tokenId].highestBidder != msg.sender && auction[_tokenId].endTime < block.timestamp, "Your auction is running");
        require(pending_claim_auction[msg.sender][_tokenId] != 0, "You are not a bidder or already claimed");
        token.transfer(msg.sender, pending_claim_auction[msg.sender][_tokenId]);
        emit AuctionClaimed(0, msg.sender, _tokenId, pending_claim_auction[msg.sender][_tokenId], block.timestamp);
        delete bid_info[msg.sender][_tokenId];
        pending_claim_auction[msg.sender][_tokenId] = 0;
    }    

    /// @dev Returns auction info for an NFT on auction.
    /// @param _auctionId - _auctionId of NFT on auction.
    function getAuction(uint256 _auctionId)
        public
        view
        virtual
        returns (AuctionDetails memory)
    {
        return (auction[_auctionId]);
    }

    /// @dev Returns auction info for an NFT on auction.
    /// @param _tokenId - ID of NFT on auction.
    function getpending_claim_auction(address _user, uint256 _tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return pending_claim_auction[_user][_tokenId];
    }

    /// @dev Returns offer info for an NFT on offer.
    /// @param _tokenId - ID of NFT on offer.
    function getpending_claim_offer(address _user, uint256 _tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return pending_claim_offer[_user][_tokenId];
    }

    /// @dev Returns sell NFT token price.
    /// @param _tokenId - ID of NFT.
    // function getSellTokenPrice(IERC1155 nftToken, uint256 _tokenId) public view returns (uint256) {
    //     return token_price[nftToken][_tokenId];
    // }

    /// @dev Buy from open sell.
    /// Transfer NFT ownership to buyer address.
    /// @param sellId - Sale ID of NFT on buy.
    /// @param _amount  - Seller set the price (in token) of NFT token.
    function buy(uint256 sellId, uint256 _amount, uint256 _quantity) public {
        IERC1155 nftToken = saleIdToNFT[sellId]; 
        uint256 _tokenId = saleIdToTokenId[sellId];
        require(msg.sender != EnumerableMap.get(saleId, sellId), "Owner can't buy");
        require(saleTokenQuantity[sellId]>=_quantity, "Not enough quantity for sale");
        require(
             EnumerableMap.get(saleId, sellId) != address(0) && token_price[sellId] > 0,
            "Token not for sell"
        );
        require(_amount >= token_price[sellId]*_quantity, "Your amount is less");
 
        nft_token.safeTransferFrom(address(this), msg.sender, _tokenId, _quantity, "");
        if(sell_service_fee == true) {
            token.transferFrom(
                msg.sender,
                beneficiary,
                ((_amount * sell_token_fee) / 100)
            );
            // emit SellFee(
            //     tokenIdToSaleId[nftToken][_tokenId],
            //     _tokenId,
            //     ((offer[_tokenId].price * sell_token_fee) / 100),
            //     block.timestamp
            // );
            token.transferFrom(
                msg.sender,
                EnumerableMap.get(saleId, _tokenId),
                ((_amount * (100 - sell_token_fee)) / 100)
            );   
        }else{
            token.transferFrom(
                msg.sender,
                EnumerableMap.get(saleId, sellId),
                _amount 
            );  
        }  

        emit Buy(
            tokenIdToSaleId[nftToken][_tokenId],
            msg.sender,
            _tokenId,
            EnumerableMap.get(saleId, sellId),
            _amount,
            _quantity,
            block.timestamp
        );

        if((saleTokenQuantity[sellId]-_quantity)==0)
        {
            delete token_price[sellId];
            delete totalOffer[sellId];
            delete saleTokenQuantity[sellId];

            for(uint256 i = 0; i < saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length; i++){
                if(saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][i] == _tokenId){
                    saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][i] = saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length-1];
                    delete saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length-1];
                    break; 
                }
            }
            EnumerableMap.remove(saleId, tokenIdToSaleId[nftToken][_tokenId]);    
            delete tokenIdToSaleId[nftToken][_tokenId];
        }
        else 
        saleTokenQuantity[sellId]=saleTokenQuantity[sellId]-_quantity;             
    }

    /// @dev Creates a new sell.
    /// Transfer NFT ownership to this contract.
    /// @param _tokenId - ID of NFT on sell.
    /// @param _unitprice   - Seller set the price (in token) of NFT token.
    function sell(IERC1155 nftToken, uint256 _tokenId, uint256 _unitprice, uint256 _quantity) public {
        require(_unitprice > 0, "Price must be greater than zero");
        require(_quantity > 0, "Quantity must be greater than zero");
        require(nftToken.balanceOf(msg.sender, _tokenId)>0, "Only owner"); 
        require(nftToken.isApprovedForAll(msg.sender,address(this)), "Token not approved");        

        currentSaleId++;

        /// token unit price for sell
        token_price[currentSaleId] = _unitprice;
        saleTokenQuantity[currentSaleId] = _quantity;
        saleIdToNFT[currentSaleId] = nftToken;
        saleIdToTokenId[currentSaleId] = _tokenId;

        //tokenIdToSaleId[nftToken][nftToken][_tokenId] = currentSaleId;
        EnumerableMap.set(saleId, currentSaleId, msg.sender);
        saleTokenIds[msg.sender][nftToken].push(_tokenId);
        nftToken.safeTransferFrom(msg.sender, address(this), _tokenId, _quantity, "");
        emit Sell(currentSaleId, msg.sender, nftToken, _tokenId, _unitprice, _quantity, block.timestamp);
    }

    /// @dev Removes token from the list of open sell.
    /// Returns the NFT to original owner.
    /// @param sellId - Sell ID of NFT on sell.
    function cancelSell(uint256 sellId) public {
        IERC1155 nftToken = saleIdToNFT[sellId];
        uint256 _tokenId = saleIdToTokenId[sellId];
        require(msg.sender ==  EnumerableMap.get(saleId, sellId) || msg.sender == owner(), "Only owner");
        require(token_price[sellId] > 0, "Can't cancel the sell");
        nft_token.safeTransferFrom(address(this), EnumerableMap.get(saleId, sellId), _tokenId, saleTokenQuantity[currentSaleId], "");
        delete token_price[sellId];
        currentSaleId--;
        for(uint256 i = 0; i < saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length; i++) {
            if(saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][i] == _tokenId) {
                saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][i] = saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length-1];
                delete saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken][saleTokenIds[EnumerableMap.get(saleId, sellId)][nftToken].length-1];
                break;
            }
        }
        EnumerableMap.remove(saleId, tokenIdToSaleId[nftToken][_tokenId]);      
        emit SellCancelled(tokenIdToSaleId[nftToken][_tokenId], msg.sender, _tokenId, block.timestamp);
        //delete tokenIdToSaleId[nftToken][_tokenId];
    }


    /// @dev Removes an auction from the list of open auctions.
    /// Returns the NFT to original owner.
    /// @param _tokenId - ID of NFT on auction.
    // function cancelAuction(uint256 _tokenId) public {
    //     require(msg.sender ==  EnumerableMap.get(auctionId, _tokenId) || msg.sender == owner(), "Only owner");
    //     nft_token.safeTransferFrom(address(this), EnumerableMap.get(auctionId, _tokenId), _tokenId, 1, "");
    //     for(uint256 i = 0; i < auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)].length; i++){
    //         if(auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)][i] == _tokenId){
    //             auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)][i] = auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)][auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)].length-1];
    //             delete auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)][auctionTokenIds[EnumerableMap.get(auctionId, _tokenId)].length-1];
    //             break;
    //         }
    //     }
    //     EnumerableMap.remove(auctionId, _tokenId);
    //     emit AuctionCancelled(auction[_tokenId].id, msg.sender, _tokenId, block.timestamp);
    //     delete auction[_tokenId];
    // }

    /// @dev Returns the user sell token Ids.
    function getSaleTokenId(IERC1155 nftToken, address _user) public view returns(uint256[] memory){
        return saleTokenIds[_user][nftToken];
    }

    /// @dev Returns the user auction token Ids.
    // function getAuctionTokenId(address _user) public view returns(uint256[] memory){
    //     return auctionTokenIds[_user];
    // }

    /// @dev Returns the user deal token Ids
    function getDealTokenId(address _user) public view returns(uint256[] memory){
        return dealTokenIds[_user];
    }

    /// @dev Returns the total deal length.
    function totalDeal() public view returns (uint256){
        return EnumerableMap.length(dealId);
    }

    /// @dev Returns the total sale length.
    function totalSale() public view returns (uint256){
        return EnumerableMap.length(saleId);
    }

    /// @dev Returns the total auction length.
    function totalAuction() public view returns (uint256){
        return EnumerableMap.length(auctionId);
    }

    /// @dev Returns the deal details and token Id.
    /// @param index - Index of NFT on deal.
    function dealDetails(uint256 index) public view returns (DealDetails memory dealInfo, uint256 tokenId){
        (uint256 id,) = EnumerableMap.at(dealId, index);
        return (deal[id], id);
    }

    /// @dev Returns the offer details, seller address ,token Id and price.
    /// @param index - Index of NFT on sale.
    // function saleDetails(IERC1155 nftToken, uint256 index) public view returns (OfferDetails memory offerInfo, address seller, uint256 tokenId, uint256 price){
    //     (uint256 id,) = EnumerableMap.at(saleId, index);
    //     return (offer[id], EnumerableMap.get(saleId, id), id, token_price[nftToken][id]);
    // }

    /// @dev Returns the auction details and token Id.
    /// @param index - Index of NFT on auction.
    function auctionDetails(uint256 index) public view returns (AuctionDetails memory auctionInfo, uint256 tokenId){
        (uint256 id,) =  EnumerableMap.at(auctionId, index);        
        return (auction[id], id);
    }

    /// @dev Returns sale and offer details on the basis of tokenId.
    /// @param tokenId - Id of NFT on sale.
    // function saleDetailsByTokenId(IERC1155 nftToken, uint256 tokenId) public view returns (OfferDetails memory offerInfo, address seller, uint256 price){             
    //     return (offer[tokenId], EnumerableMap.get(saleId, tokenId), token_price[nftToken][tokenId]);
    // }

    /// @dev Returns deal details on the basis of tokenId.
    /// @param tokenId - Id of NFT on deal.
    function dealDetailsByTokenId(uint256 tokenId) public view returns (DealDetails memory dealInfo){             
        return (deal[tokenId]);
    }

    /// @dev Returns all auction details.
    function getAllAuctionInfo() public view returns (AuctionDetails[] memory) {
        AuctionDetails[] memory auctionInfo = new AuctionDetails[](EnumerableMap.length(auctionId));
        for(uint256 i = 0; i < EnumerableMap.length(auctionId); i++){
            (uint256 id,) =  EnumerableMap.at(auctionId, i);  
            auctionInfo [i] = (auction[id]);
        }
        return auctionInfo;
    }

    /// @dev Returns all deal details.
    function getAllDealInfo() public view returns (DealDetails[] memory) {
        DealDetails[] memory dealInfo = new DealDetails[](EnumerableMap.length(dealId));
        for(uint256 i = 0; i < EnumerableMap.length(dealId); i++){
            (uint256 id,) =  EnumerableMap.at(dealId, i);  
            dealInfo [i] = (deal[id]);
        }
        return dealInfo;
    }

    /// @dev Returns all sale details.
    // function getAllSaleInfo(IERC1155 nftToken) public view returns(OfferDetails[] memory, address[] memory seller, uint256[] memory price, uint256[] memory tokenIds){
    //     OfferDetails[] memory offerInfo = new OfferDetails[](EnumerableMap.length(saleId));
    //     for(uint256 i = 0; i < EnumerableMap.length(saleId); i++){
    //         (uint256 id,) =  EnumerableMap.at(saleId, i);  
    //         offerInfo [i] = (offer[id]);
    //         seller[i] = EnumerableMap.get(saleId, id);
    //         price[i] =  token_price[nftToken][id];
    //         tokenIds[i] = id;
    //     }
    //     return (offerInfo, seller, price, tokenIds);
    // }

    /// @dev Returns string for token place in which market.
    /// @param tokenId - Id of NFT.
    function checkMarket(uint256 tokenId) public view returns(string memory){
        if(auction[tokenId].price > 0){
            return "Auction";
        }else if(deal[tokenId].price > 0){
            return "Deal";
        // }else if(token_price[nftToken][tokenId] > 0){
        //     return "Sale";
        }else{
            return "Not in market";
        }
    }

    function getCancelBidEnabled() public view returns(bool){
        return cancel_bid_enable;
    }

    function getCancelOfferEnabled() public view returns(bool){
        return cancel_offer_enable;
    }
}
