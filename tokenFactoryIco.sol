pragma solidity ^0.4.5;

// require module for token allocation for developers and stakeholders.
import "./TokenFactoryAllocation.sol";

contract MigrationAgent {
  function migratedFrom(address _from, uint256 _value);
}

// Token Factory ICO code
contract TokenFactoryCoin {
  string public constant name = "Token Factory Coin";
  string public constant symbol = "TFC";
  uint8 public constant decimals = 18; // same as ETH

  uint256 public constant tokenCreationRate = 1000;

  // ICO cap in weis
  uint256 public constant tokenCreationCap = 900000 ether * tokenCreationRate;
  uint256 public constant tokenCreationMin = 200000 ether * tokenCreationRate;

  uint256 public fundingStartBlock;
  uint256 public fundingEndBlock;

  // Indicated if contract is in funding state
  bool public funding = true;

  // Receives ETH and its own TFC endowment
  address public tokenFactory;

  // Has control over token migration to next version of token
  address public migrationMaster;

  TokenFactoryAllocation lockedAllocation;

  // current total current supply
  uint256 totalTokens;

  mapping (address => uint256) balances;

  address public migrationAgent;
  uint256 public totalMigrated;

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Migrate(address indexed _from, address indexed _to, uint256 _value);
  event Refund(address indexed _from, uint256 _value);

  function TokenFactoryCoin(address _tokenFactory,
                            address _migrationMaster,
                            uint256 _fundingStartBlock,
                            uint256 _fundingEndBlock)  {

    if (_tokenFactory == 0) throw;
    if (_migrationMaster == 0) throw;
    if (_fundingStartBlock <= block.number) throw;
    if (_fundingEndBlock <= _fundingStartBlock) throw;

    lockedAllocation = new TokenFactoryAllocation(_tokenFactory);
    migrationMaster = _migrationMaster;
    tokenFactory = _tokenFactory;
    fundingStartBlock = _fundingStartBlock;
    fundingEndBlock = _fundingEndBlock;
  }

  // Transfer _value TFC coins from sender's account
  // msg.sender to provide account address _to
  // this function is disabled during funding
  // dev required state: Operational
  // @param _to the of the tokens recipient
  // @param _value the amount of token to be transferred
  // @return whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool) {
    // abort if in funding state.
    if (funding) throw;

    var senderBalance = balances[msg.sender];
    if (senderBalance >= _value && _value > 0) {
      senderBalance -= _value;
      balances[_to] += _value;
      Transfer(msg.sender, _to, _value);
      return true;
    }
    return false;
  }

  function totalSupply() external constant returns (uint256) {
    return totalTokens;
  }

  function balanceOf(address _owner) external constant returns (uint256) {
    return balances[_owner];
  }

  // Token Migration Support:

  // @notice migrate tokens to the new token contract
  // @dev required state: operational migration
  // @param _value the amount of token to be migrated
  function migrate(uint256 _value) external {
    // abort if funding state
    if (funding) throw;
    if (migrationAgent == 0) throw;

    // validate input value
    if (_value == 0) throw;
    if (_value > balances[msg.sender]) throw;

    balances[msg.sender] -= _value;
    totalTokens -= _value;
    totalMigrated += _value;
    MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
    Migrate(msg.sender, migrationAgent, _value);
  }

  // @notice set address of migration target contract and enaable migration process
  // @dev required state: operational normal
  // @dev state transition: -> operational migration
  // @param _agent the address of the Migration contract
  function setMigrationAgent(address _agent) external {
    // abort if funding
    if (funding) throw;
    if (migrationAgent !=0) throw;
    if (msg.sender != migrationMaster) throw;
    migrationAgent = _agent;
  }

  function setMigrationMaster(address _master) external {
    if (msg.sender != migrationMaster) throw;
    if (_master == 0) throw;
    migrationMaster = _master;
  }

  // ICO:

  // @notice create tokens when funding is active
  // @dev required state: Funding active
  // @dev state transition: -> funding success (only if cap reached)
  function create() payable external {
    // abort if not in funding. Checks are split as opposed to || operator because it is cheaper
    if (!funding) throw;
    if (block.number < fundingStartBlock) throw;
    if (block.number > fundingEndBlock) throw;

    // Do not allow creating 0 or more than the cap tokens
    if (msg.value == 0) throw;
    if (msg.value > (tokenCreationCap - totalTokens) / tokenCreationRate) throw;

    var numTokens = msg.value * tokenCreationRate;
    totalTokens += numTokens;

    // assign new tokens to the sender
    balances[msg.sender] += numTokens;
  }

  // @notice finalize crowdfunding
  // @dev if cap was reached or crowdfunding has ended then:
  // create TFC for Token Factory and developer,
  // transfer ETH to the Token factory address.
  // @dev required state: funding success
  // @dev state transition: -> funding success
  function finalize() external {
    if (!funding) throw;
    if (( block.number <= fundingEndBlock || totalTokens < tokenCreationMin) && totalTokens < tokenCreationCap) throw ;

    // switch to operation state. Only place this can happen.
    funding = false;

    // create additional TFC for Token Factory and develoers as 10% of total number of tokens
    // all aditional tokens are transferred to the account controller by
    // TFCAllocation contract which will not allow using them for X months.

    uint256 percentOfTotal = 10;
    uint256 additionalTokens = totalTokens * percentOfTotal / (100 = percentOfTotal);
    totalTokens += additionalTokens;
    balances[lockedAllocation] += additionalTokens;
    // transfer ETH to Token Factory address
    Transfer(0, lockedAllocation, additionalTokens);

    if (!tokenFactory.send(this.balance)) throw;
  }

  // @notice get back ETH sent during the funding in case the funding has not reached the minimum amount required
  // @dev required state: funding failure
  function refund() external {
    // abort if not funding
    if (!funding) throw;
    if (block.number <= fundingEndBlock) throw;
    if (totalTokens >= tokenCreationMin) throw;

    var tfcValue = balances[msg.sender];
    if (tfcValue == 0) throw;
    balances[msg.sender] = 0;
    totalTokens -= tfcValue;

    var ethValue = tfcValue / tokenCreationRate;
    Refund(msg.sender, ethValue);
   if (!msg.sender.send(ethValue)) throw;
  }
}
