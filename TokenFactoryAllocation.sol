pragma solidity ^0.4.5;

import "./tokenFactoryIco.sol";

/// @title token factory Allocation - Time-locked vault of tokens allocated
/// to developers and token Factory
contract TokenFactoryAllocation {
    // Total number of allocations to distribute additional tokens among
    // developers and the Token Factory. The Token Factory has right to 20000
    // allocations, developers to 10000 allocations, divides among individual
    // developers by numbers specified in  `allocations` table.
    uint256 constant totalAllocations = 30000;

    // Addresses of developer and the Token Factory to allocations mapping.
    mapping (address => uint256) allocations;

    TokenFactoryCoin tfc;
    uint256 unlockedAt;

    uint256 tokensCreated = 0;

    function TokenFactoryAllocation(address _tokenFactory) internal {
        tfc = TokenFactoryCoin(msg.sender);
        unlockedAt = now + 30 days;

        // For the Token Factory:
        allocations[_tokenFactory] = 20000;

        //for developers ???

    }

    /// @notice Allow developer to unlock allocated tokens by transferring them
    /// from TokenFactoryAllocation to developer's address.
    function unlock() external {
        if (now < unlockedAt) throw;

        // During first unlock attempt fetch total number of locked tokens.
        if (tokensCreated == 0)
            tokensCreated = tfc.balanceOf(this);

        var allocation = allocations[msg.sender];
        allocations[msg.sender] = 0;
        var toTransfer = tokensCreated * allocation / totalAllocations;

        // Will fail if allocation (and therefore toTransfer) is 0.
        if (!tfc.transfer(msg.sender, toTransfer)) throw;
    }
}
