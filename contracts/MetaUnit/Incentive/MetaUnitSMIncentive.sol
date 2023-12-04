// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Pausable} from "../../utils/Pausable.sol";
import {IMetaUnitTracker} from "../../utils/IMetaUnitTracker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @author MetaPlayerOne DAO
 * @title MetaUnitSMIncentive
 */
contract MetaUnitSMIncentive is Pausable, ReentrancyGuard {
    struct Token { address token_address; uint256 token_id; bool is_single; }

    address private immutable _meta_unit_address;
    address private immutable _meta_unit_tracker_address;
    uint256 private immutable _contract_deployment_timestamp;

    mapping(address => uint256) private _value_minted_by_user_address;
    mapping(address => bool) private _is_committee;

    uint256 private _coeficient_min = 0.1;
    uint256 private _coeficient_max = 10;
    uint256 private _coeficient = 2;
    address[] private _voted;

    /**
    * @dev setup MetaUnit address and owner of this contract.
    */
    constructor(address owner_of_, address meta_unit_address_, address meta_unit_tracker_address_, address[] memory committee_) Pausable(owner_of_) {
        _meta_unit_address = meta_unit_address_;
        _contract_deployment_timestamp = block.timestamp;
        _meta_unit_tracker_address = meta_unit_tracker_address_;
        for (uint256 i = 0; i < committee_.length; i++) {
            _is_committee[committee_[i]] = true;
        }
    }

    /**
     * @return value multiplied by the time factor.
     */
    function getReducedValue(uint256 value) private view returns (uint256) {
        return (((value * _contract_deployment_timestamp) / (((block.timestamp - _contract_deployment_timestamp) * (_contract_deployment_timestamp / 547 days)) + _contract_deployment_timestamp)) * _coeficient / 1 ether);
    }
    
    /**
     * @dev manages secondary mint of MetaUnit token.
     */
    function secondaryMint() public notPaused nonReentrant {
        IMetaUnitTracker tracker = IMetaUnitTracker(_meta_unit_tracker_address);
        uint256 value_for_mint = tracker.getUserResalesSum(msg.sender);
        uint256 quantity_of_transaction = tracker.getUserTransactionQuantity(msg.sender);
        require(_value_minted_by_user_address[msg.sender] < value_for_mint * quantity_of_transaction, "Not enough tokens for mint");
        uint256 value = (value_for_mint * quantity_of_transaction) - _value_minted_by_user_address[msg.sender];
        IERC20(_meta_unit_address).transfer(msg.sender, getReducedValue(value));
        _value_minted_by_user_address[msg.sender] += getReducedValue(value);
    }

    function setCoeficient(uint256 coeficient_) public {
        require(msg.sender == _owner_of, "Permission denied");
        require(coeficient_ >= _coeficient_min, "Value too small");
        require(coeficient_ <= _coeficient_max, "Value too big");
        _coeficient = coeficient_;
    }

    function withdraw() external {
        require(_is_committee[msg.sender], "Permission denied");
        uint256 voted_length = _voted.length;
        for (uint256 i; i < voted_length; i++) {
            require(_voted[i] != msg.sender, "Already voted");
        }
        IERC20 metaunit = IERC20(_meta_unit_address);
        require(metaunit.balanceOf(address(this)) > 0, "Not enough");
        _voted.push(msg.sender);
        if (_voted.length == 3) {
            metaunit.transfer(_owner_of, metaunit.balanceOf(address(this)));
            delete _voted;
        }
    }

}
