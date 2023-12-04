// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CrystalOfMetaplayer is ERC721, ICrystalOfPower {
    uint256 private quantity;
    string private project_uri;
    address private shard_crystal_address;
    address private project_address;
    uint256 private drop_amount = 0;
    uint256 private limit = 500;
    mapping(address => bool) white_list_addresses;
    mapping(address => bool) gold_list_addresses;

    constructor(
        string memory _project_uri,
        address _shard_crystal_address,
        address _project_address
    ) ERC721("Crystal of Metaplayer", "Crystal of Metaplayer") {
        project_uri = _project_uri;
        shard_crystal_address = _shard_crystal_address;
        project_address = _project_address;
    }

    modifier checkMint() {
        require(quantity + 1 <= limit, "Limit exceeded. Max: 700");
        require(
            balanceOf(msg.sender) == 0,
            "Limit exceeded. Max: 1 per wallet."
        );
        if (gold_list_addresses[msg.sender]) {
            require(msg.value >= 4 * 4 * 10**17, "Not enough funds send");
        } else if (white_list_addresses[msg.sender]) {
            require(msg.value >= 4 * 45 * 10**16, "Not enough funds send");
        } else {
            require(msg.value >= 4 * 55 * 10**16, "Not enough funds send");
        }
        require(
            IERC721(shard_crystal_address).balanceOf(msg.sender) >= 4,
            "Not enough MetaSkynet Shard Crystals in your wallet. Min: 4"
        );
        _;
    }

    function mint() public payable override checkMint {
        quantity += 1;
        _mint(msg.sender, quantity);
        payable(project_address).transfer(msg.value);
    }

    function mintOther(uint256 _amount) public {
        require(msg.sender == project_address, "Permission denied");
        for (uint256 i = 0; i < _amount; i++) {
            quantity += 1;
            _mint(msg.sender, quantity);
        }
    }

    function setWhiteList(address[] memory addresses) public {
        require(msg.sender == project_address, "Permission denied");
        for (uint256 i = 0; i < addresses.length; i++) {
            white_list_addresses[addresses[i]] = true;
        }
    }

    function setGoldList(address[] memory addresses) public {
        require(msg.sender == project_address, "Permission denied");
        for (uint256 i = 0; i < addresses.length; i++) {
            gold_list_addresses[addresses[i]] = true;
        }
    }

    function setLimit(uint256 _amount) public {
        require(msg.sender == project_address, "Permission denied");
        require(_amount <= limit, "Limit exceeded. Max: 700");
        drop_amount = _amount;
    }

    function isGoldList() public view returns (bool) {
        return gold_list_addresses[msg.sender];
    }

    function isWhiteList() public view returns (bool) {
        return white_list_addresses[msg.sender];
    }

    function tokenURI(uint256 token_id)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(token_id), "Token does not exist");
        return project_uri;
    }
}
