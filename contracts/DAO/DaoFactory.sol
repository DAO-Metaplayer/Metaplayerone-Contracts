// SPDX-License-Identifier: MIT

import { IERC20Dao } from "../utils/ERC20/IERC20Dao.sol";
import { Pausable } from "../utils/Pausable.sol";

pragma solidity ^0.8.0;

/**
 * @author MetaPlayerOne DAO
 * @title DaoFactory
 * @notice Contract which manages daos in MetaPlayerOne.
 */
contract DaoFactory is Pausable {
    mapping(address => address[]) private _daos_by_owner;
    mapping(address => address) private _owner_by_dao;
    mapping(address => bool) private _is_activated;

    /**
     * @dev setup owner of this contract.
     */
    constructor(address owner_of_) Pausable(owner_of_) {}

    /**
     * @dev emits when new dao has been added to DaoFactory.
     */
    event daoCreated(
        string name,
        string symbol,
        address owner_of,
        uint256 presale,
        uint256 limit,
        uint256 price,
        address token_address,
        address join_address,
        bool created
    );

    /**
     * @dev function which creates dao with params.
     * @param token_address token address of ERC20 which you want to add to DaoFactory.
     */
    function addDao(address token_address) public notPaused {
        require(!_is_activated[token_address], "Dao is already activated");
        IERC20Dao token = IERC20Dao(token_address);
        _is_activated[token_address] = true;
        emit daoCreated(
            token.name(),
            token.symbol(),
            address(0),
            0,
            0,
            0,
            token_address,
            address(0),
            false
        );
    }

    /**
     * @dev function which creates dao with params.
     * @param owner_of address of user, which daos should be returned
     * @return address list of dao addresses which this user register
     */
    function getDaosByOwner(
        address owner_of
    ) public view returns (address[] memory) {
        return _daos_by_owner[owner_of];
    }

    /**
     * @dev function which creates dao with params.
     * @param dao_address includes name of project, project description and project banner and project logo
     * @return owner_of returns owner of requested dao.
     */
    function getDaoOwner(address dao_address) public view returns (address) {
        return _owner_by_dao[dao_address];
    }
}
