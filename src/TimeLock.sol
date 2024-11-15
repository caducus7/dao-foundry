//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TimelockController} from "@openzeppelin/contracts/governance//TimelockController.sol";

contract TimeLock is TimelockController {
    /*
    *@param minDelay : how long you have to wait before executing
    *@param proposers : list of address that can propose
    *@param executors : list of addresses that can executre
    *@param admin : address of the admin // we use msg.sender for now
    */

    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
