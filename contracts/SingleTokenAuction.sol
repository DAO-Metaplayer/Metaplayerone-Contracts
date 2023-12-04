// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IMetaUnitTracker} from "./utils/IMetaUnitTracker.sol";
import {Pausable} from "./utils/Pausable.sol";
import {IFeeStorage} from "./utils/ERC721/IFeeStorage.sol";

/**
 * @author MetaPlayerOne DAO
 * @title SingleTokenAuction
 */
contract SingleTokenAuction is Pausable, ReentrancyGuard {
    struct Item { uint256 uid; address token_address; uint256 token_id; address owner_of; address curator_address; uint256 curator_fee; uint256 start_price; bool approved; uint256 highest_bid; address highest_bidder; uint256 end_time; uint256 duration; }

    Item[] private _items;
    mapping(address => mapping(uint256 => mapping(address => bool))) private _active_items;
    mapping(address => uint256) availableClaim;
    mapping(uint256 => bool) private _finished;

    address private immutable _meta_unit_tracker_address;
    address private immutable _creator_fee_storage;
  
    constructor(address owner_of_, address meta_unit_tracker_address_, address creator_fee_storage_) Pausable(owner_of_) {
        _meta_unit_tracker_address = meta_unit_tracker_address_;
        _creator_fee_storage = creator_fee_storage_;
    }
   
    event itemAdded(uint256 uid, address token_address, uint256 token_id, address owner_of, address curator_address, uint256 curator_fee, uint256 start_price, bool approved, uint256 highest_bid, address highest_bidder,uint256 end_time);
    event auctionApproved(uint256 uid, uint256 end_time);
    event bidAdded(uint256 uid, uint256 highest_bid, address highest_bidder);
    event itemResolved(uint256 uid);

    function sale(address token_address, uint256 token_id, address curator_address, uint256 curator_fee, uint256 start_price, uint256 duration) public notPaused nonReentrant {
        require(curator_address != address(0), "Curator address should not be 0x0");
        require(curator_fee <= 200, "");
        require(IERC721(token_address).supportsInterface(0x80ac58cd), "Token is not ERC721");
        require(IERC721(token_address).ownerOf(token_id) == msg.sender, "You are not an owner");
        require(IERC721(token_address).getApproved(token_id) == address(this), "Token is not approved to contract");
        require(!_active_items[token_address][token_id][msg.sender], "Item is already on sale");        
        uint256 _start_price_non_zero = start_price == 0 ? 1 ether : start_price; 
        try IERC2981(token_address).royaltyInfo(token_id, _start_price_non_zero) returns (address, uint256 royalty_fee_) {
            require(royalty_fee_ * 10000 / _start_price_non_zero <= 3000, "Royalty fee too big");
        } catch {}
        uint256 newItemId = _items.length;
        _items.push(Item(newItemId, token_address, token_id, msg.sender, curator_address, curator_fee, start_price, false, 0, address(0), 0, duration));
        _active_items[token_address][token_id][msg.sender] = true;
        emit itemAdded(newItemId, token_address, token_id, msg.sender, curator_address, curator_fee, start_price, false, 0, address(0), duration);
        if (curator_address == msg.sender) {
            setCuratorApproval(newItemId);
        }
    }

    function setCuratorApproval(uint256 uid) public notPaused {
        require(uid < _items.length && _items[uid].uid == uid, "Token does not exists");
        Item memory item = _items[uid];
        require(!item.approved, "Auction is already approved");
        require(item.curator_address == msg.sender, "You are not curator");
        _items[uid].approved = true;
        _items[uid].end_time = block.timestamp + item.duration;
        emit auctionApproved(uid, _items[uid].end_time);
    }

    function bid(uint256 uid) public payable nonReentrant {
        require(uid < _items.length && _items[uid].uid == uid, "Order does not exists");
        Item memory item = _items[uid];
        IERC721 token = IERC721(item.token_address);
        require(block.timestamp <= item.end_time, "Auction has been finished");
        require(token.getApproved(item.token_id) == address(this), "Token is not approved to contract");
        require(token.ownerOf(item.token_id) == item.owner_of, "Token is already sold");
        require(item.approved, "Auction is not approved");
        require(msg.value > item.start_price, "Bid is lower than start price");
        require(msg.value > item.highest_bid, "Bid is lower than previous one");
        require(item.owner_of != msg.sender, "You are an owner of this auction");
        require(item.curator_address != msg.sender, "You are an curator of this auction");
        if (item.highest_bidder != address(0)) {
            availableClaim[item.highest_bidder] += item.highest_bid;
        }
        _items[uid].highest_bid = msg.value;
        _items[uid].highest_bidder = msg.sender;
        emit bidAdded(uid, _items[uid].highest_bid, _items[uid].highest_bidder);
    }

    function claim() public nonReentrant {
        uint256 credit = availableClaim[msg.sender];
        require(credit > 0 && address(this).balance >= credit, "Claim failed");
        availableClaim[msg.sender] = 0;
        payable(msg.sender).transfer(credit);
    }

    function resolve(uint256 uid) public notPaused nonReentrant {
        require(uid < _items.length && _items[uid].uid == uid, "Order does not exists");
        Item memory item = _items[uid];
        IERC721 token = IERC721(item.token_address);
        require(block.timestamp >= item.end_time, "Auction does not finish");
        require(item.curator_address == msg.sender, "You are not curator");
        require(item.approved, "Auction is not approved");
        require(token.getApproved(item.token_id) == address(this), "Token is not approved to contract");
        require(!_finished[uid], "Auction has been resolved");
        if (item.highest_bidder != address(0)) {
            uint256 creator_fee_total = 0;
            address royalty_fee_receiver = address(0);
            uint256 royalty_fee = 0;
            bool sent_creator = true;
            try IFeeStorage(_creator_fee_storage).feeInfo(item.token_address, item.highest_bid) returns (address[] memory creator_fee_receiver_, uint256[] memory creator_fee_, uint256 total_) {
                for (uint256 i = 0; i < creator_fee_receiver_.length; i ++) {
                    (bool _sent_creator,) = payable(creator_fee_receiver_[i]).call{value: creator_fee_[i]}("");
                    if (!_sent_creator) sent_creator = false;
                }
                creator_fee_total = total_;
            } catch {}
            require(sent_creator, "Creator fee transfer failed");
            try IERC2981(item.token_address).royaltyInfo(item.token_id, item.highest_bid) returns (address royalty_fee_receiver_, uint256 royalty_fee_) {
                royalty_fee_receiver = royalty_fee_receiver_;
                royalty_fee = royalty_fee_;
            } catch {}
            uint256 project_fee = (item.highest_bid * 25) / 1000;
            uint256 curator_fee = (item.highest_bid * item.curator_fee) / 1000;
            if (royalty_fee_receiver != address(0)) {
                (bool sent_royalty_fee,) = payable(royalty_fee_receiver).call{value: royalty_fee}("");
                require(sent_royalty_fee, "Royalty fee transfer failed");
            }
            (bool sent_project,) = payable(_owner_of).call{value: project_fee}("");
            (bool sent_curator,) = payable(item.curator_address).call{value: curator_fee}("");
            (bool sent_owner,) = payable(item.owner_of).call{value: (item.highest_bid - creator_fee_total - royalty_fee - project_fee - curator_fee)}("");
            require(sent_project && sent_curator && sent_owner, "Rewards transfer failed");
            IMetaUnitTracker(_meta_unit_tracker_address).track(item.owner_of, item.highest_bid);
            IERC721(item.token_address).safeTransferFrom(item.owner_of, item.highest_bidder, item.token_id);
        }
        _finished[uid] = true;
        _active_items[item.token_address][item.token_id][item.owner_of] = false;
        emit itemResolved(uid);
    }
}
