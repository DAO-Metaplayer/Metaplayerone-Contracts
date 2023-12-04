// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOwnable {
    function owner() external view returns (address);
}

contract FeeStorage {
    struct FeeReceiver { address ethAddress; uint256 fee; }
    mapping(address => FeeReceiver[]) private _fee_receivers;

    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function setReceivers(address token_address_, address[] memory fee_receivers_, uint256[] memory fee_amount_) public {
        require(fee_receivers_.length == fee_amount_.length, "Wrong input");
        try IOwnable(token_address_).owner() returns (address owner_of) {
            require(owner_of == msg.sender, "Permission denied");
        } catch {
            revert("Contract is now Ownable");
        }
        uint256 total = 0;
        for (uint256 i = 0; i < fee_receivers_.length; i++) {
            total += fee_amount_[i];
        }
        require(total < 2000, "Max. value 20%");
        delete _fee_receivers[token_address_];
        for (uint256 i = 0; i < fee_receivers_.length; i++) {
            _fee_receivers[token_address_].push(FeeReceiver(fee_receivers_[i], fee_amount_[i]));
        }
    }

    function feeInfo(address token_address, uint256 salePrice)
        public
        view
        returns (address[] memory, uint256[] memory, uint256)
    {
        address[] memory addresses = new address[](_fee_receivers[token_address].length);
        uint256[] memory fees = new uint256[](_fee_receivers[token_address].length);
        uint256 total = 0;

        for (uint256 i = 0; i < _fee_receivers[token_address].length; i++) {
            addresses[i] = _fee_receivers[token_address][i].ethAddress;
            fees[i] = _fee_receivers[token_address][i].fee * salePrice / _feeDenominator();
            total += _fee_receivers[token_address][i].fee * salePrice / _feeDenominator();
        }

        return (addresses, fees, total);
    }
}
