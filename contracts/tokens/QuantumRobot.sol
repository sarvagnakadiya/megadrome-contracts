// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract QuantumRobot is ERC20, Ownable, ERC20Permit {
    constructor() ERC20("Quantum Robot", "QUBOT") ERC20Permit("Quantum Robot") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
