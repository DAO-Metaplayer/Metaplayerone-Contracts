// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "../../utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MetaUnitFMIncentive is Pausable, ReentrancyGuard {
    mapping(address => bool) private _is_first_mint_resolved;
    address private immutable _meta_unit_address;
    uint256 private _value;
    mapping(address => bool) private _is_committee;
    address[] private _voted;

    constructor(address owner_of_, address meta_unit_address_, address[] memory committee_) Pausable(owner_of_) {
        _meta_unit_address = meta_unit_address_;
        _value = 4 ether;
        for (uint256 i = 0; i < committee_.length; i++) {
            _is_committee[committee_[i]] = true;
        }
    }

    function firstMint() public notPaused nonReentrant {
        require(!_is_first_mint_resolved[msg.sender], "You have already performed this action");
        IERC20(_meta_unit_address).transfer(msg.sender, _value);
        _is_first_mint_resolved[msg.sender] = true;
    }

    function isFirstMintResolved(address user_address) public view returns (bool) {
        return _is_first_mint_resolved[user_address];
    }

    function setValue(uint256 value_) public {
        require(msg.sender == _owner_of, "Permission denied");
        _value = value_;
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
