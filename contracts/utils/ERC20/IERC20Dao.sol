// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20Dao {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function getJoinContract() external returns (address);
}
