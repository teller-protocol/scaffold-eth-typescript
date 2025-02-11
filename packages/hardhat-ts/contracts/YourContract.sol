pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract YourContract is Ownable {
    event SetPurpose(address sender, string purpose);

    error EmptyPurposeError(uint256 code, string message);

    string public _purpose = "Building Unstoppable Apps";

    constructor() {
        // what should we do on deploy?
    }

    function purpose() public view returns (string memory) {
        return _purpose;
    }

    function setPurpose(string memory newPurpose) public payable {
        if (bytes(newPurpose).length == 0) {
            revert EmptyPurposeError({
                code: 1,
                message: "Purpose can not be empty"
            });
        }

        _purpose = newPurpose;
        console.log(msg.sender, "set purpose to", _purpose);
        emit SetPurpose(msg.sender, _purpose);
    }
}
