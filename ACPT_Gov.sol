// ACCPROT-GOV-TITLE: 
/* BEGIN-ACCPROT-GOV-DESC  
END-ACCPROT-GOV-DESC */ 

pragma solidity ^0.6.0;

contract Governance  {
    using SafeMath for uint;

    // Governance Parameters
    uint public governanceExpiry      = 7 days;    // Duration for which governance votes can be collected
    uint public governanceSwitchDelay = 1 minutes; // Duration before next governance module can be loaded
    uint public voteQuorum            = 5;         // Quorum to approve new governance
    uint public votePass              = 50;        // Percentage required to approve new governance
    uint public minGovToken           = 1;         // Percentage tokens required to create new proposal 
    uint public voteDecimal           = 100;       // Divisor for voteQuorum and votePass
    
    // Address Management
    address public previousGovernance     = ?;    // Address of previous governance
    address [] public OptionsPools        = [?];  // OptionPools Addresses
    address public GovernanceTokenAddress = ?;    // GovernanceTokenAddress

    // Oracle Parameters
    address public oracleAddress          = ?;    // Current Oracle Address
    address public approvedOracleSource   = 0xfCEAdAFab14d46e20144F48824d0C09B1a03F2BC ;   // Approved Oracle Source - CoinbasePro
    
    constructor () public {
        _expiryOffsetBase [ OptionsPools[0] ] = 60 minutes;
        _expiryOffset     [ OptionsPools[0] ] = 10 minutes;
        _bidPeriod        [ OptionsPools[0] ] =  5 minutes;
        _maxOraclePriceAge[ OptionsPools[0] ] =  5 minutes;
        _minStrikePriceGap[ OptionsPools[0] ] =    5000000;
        _minIncrement     [ OptionsPools[0] ] =    1010000;
        _maxCollateral    [ OptionsPools[0] ] =   10000e18;
    }

    // Function executed automatically when executeGovernance is called
    function executeGovernanceActions() public {
        require(msg.sender == previousGovernance, "!PrevGov");
    }

    address public nextGovernance;            // Next governance module
    uint    public nextGovernanceExecution;   // Timestamp before governance module is executed
    address [] public proposedGovernanceList; // List of proposed governance modules
    bool    public GovernanceSwitchExecuted;  // Governance Changed. 
    
    // Pool Parameters
    
    mapping (address => uint) public _expiryOffsetBase;               // Minimum expiry period. 1 days means expiry offers must happens in daily intervals
    mapping (address => uint) public _expiryOffset;                   // Which second within the base period to be used for expiry - Used to match with other target markets. 
    mapping (address => uint) public _bidPeriod;                      // Duration which bids are accepted
    mapping (address => uint) public _maxOraclePriceAge;              // Validity of oracle prices
    mapping (address => uint) public _minStrikePriceGap;              // Strike offer must be this far from oracle price (Divisor = 1,000,000)
    mapping (address => uint) public _minIncrement;                   // Minimum increment for bids (APR or strike) (Divisor = 1,000,000)
    mapping (address => uint) public _maxCollateral;                  // For safety, capping each pool's max collateral supply
    
    
    
    // Voting Storage
    mapping (address => mapping (address => uint)) public voteYes;  // Yes votes collected 
    mapping (address => mapping (address => uint)) public voteNo;   // No votes collected

    mapping (address => uint) public voteYesTotal;     // Total Yes votes collected 
    mapping (address => uint) public voteNoTotal;      // Total No votes collected
    mapping (address => uint) public dateIntroduced;   // Timestamp when contract is proposed
    mapping (address => bool) public tokenLocked;      // Tokens locked


    function expiryOffsetBase()          public view returns (uint) { 
        return _expiryOffsetBase[msg.sender];
    }
    
    function expiryOffset()              public view returns (uint) { 
        return _expiryOffset[msg.sender];
    }
    
    function bidPeriod()                 public view returns (uint) { 
        return _bidPeriod[msg.sender];
    }
    
    function maxOraclePriceAge()         public view returns (uint) { 
        return _maxOraclePriceAge[msg.sender];
    }
    
    function minStrikePriceGap()         public view returns (uint) { 
        return _minStrikePriceGap[msg.sender];
    }

    function minIncrement()              public view returns (uint) { 
        return _minIncrement[msg.sender];
    }
    
    function maxCollateral()             public view returns (uint) { 
        return _maxCollateral[msg.sender];
    }
    
    
    function proposeNewGovernance(address newGovernanceContract) public {
        require(tokenLocked[msg.sender] == false, "Locked");
        require(GovernanceToken(GovernanceTokenAddress).balanceOf(msg.sender).mul(voteDecimal).div( GovernanceToken(GovernanceTokenAddress).totalSupply() ) > minGovToken, "<InsufGovTok" );
        require(Governance(newGovernanceContract).previousGovernance() == address(this), "WrongGovAddr");
        require(dateIntroduced[newGovernanceContract] == 0, "AlreadyProposed");
        tokenLocked[msg.sender] = true;
        proposedGovernanceList.push(newGovernanceContract);
        dateIntroduced[newGovernanceContract] = now;
    }
    
    function clearExistingVotesForProposal(address newGovernanceContract) public {
        voteYesTotal[newGovernanceContract] = voteYesTotal[newGovernanceContract].sub( voteYes[newGovernanceContract][msg.sender] );
        voteNoTotal [newGovernanceContract] = voteNoTotal [newGovernanceContract].sub( voteNo [newGovernanceContract][msg.sender] );
        voteYes[newGovernanceContract][msg.sender] = 0;
        voteNo [newGovernanceContract][msg.sender] = 0;
        
    }
    
    function voteYesForProposal(address newGovernanceContract) public {
        require(dateIntroduced[newGovernanceContract].add(governanceExpiry) > now , "ProposalExpired");
        require( nextGovernance == address(0), "AlreadyQueued");
        tokenLocked[msg.sender] = true;
        clearExistingVotesForProposal(newGovernanceContract);
        voteYes[newGovernanceContract][msg.sender] = GovernanceToken(GovernanceTokenAddress).balanceOf(msg.sender);
        voteYesTotal[newGovernanceContract] = voteYesTotal[newGovernanceContract].add( GovernanceToken(GovernanceTokenAddress).balanceOf(msg.sender) );
    }
    
    function voteNoForProposal(address newGovernanceContract) public {
        require(dateIntroduced[newGovernanceContract].add(governanceExpiry) > now , "ProposalExpired");
        require( nextGovernance == address(0), "AlreadyQueued");
        tokenLocked[msg.sender] = true;
        clearExistingVotesForProposal(newGovernanceContract);
        voteNo[newGovernanceContract][msg.sender] = GovernanceToken(GovernanceTokenAddress).balanceOf(msg.sender);
        voteNoTotal[newGovernanceContract] = voteNoTotal[newGovernanceContract].add( GovernanceToken(GovernanceTokenAddress).balanceOf(msg.sender) );
    }
    
    function queueGovernance(address newGovernanceContract) public {
        require( voteYesTotal[newGovernanceContract].add(voteNoTotal[newGovernanceContract]).mul(voteDecimal).div( GovernanceToken(GovernanceTokenAddress).totalSupply() ) > voteQuorum, "<Quorum" );
        require( voteYesTotal[newGovernanceContract].mul(voteDecimal).div( voteYesTotal[newGovernanceContract].add(voteNoTotal[newGovernanceContract]) ) > votePass, "<Pass" );
        require( nextGovernance == address(0), "AlreadyQueued");
        nextGovernance = newGovernanceContract;
        nextGovernanceExecution = now.add(governanceSwitchDelay);
    }  
    
    function executeGovernance() public {
        require( nextGovernance != address(0) , "!Queued");
        require( now > nextGovernanceExecution, "!NotYet");
        require( GovernanceSwitchExecuted == false, "AlrExec");
        for (uint i = 0; i < OptionsPools.length; i++) {
            OptionPool( OptionsPools[i] ).setGovernance(nextGovernance);
        }
        GovernanceToken(GovernanceTokenAddress).setGovernance(nextGovernance);
        Governance(nextGovernance).executeGovernanceActions();
        GovernanceSwitchExecuted = true;
    }

    function oracle_getPrice(string memory key) public view returns (uint64) {
        return OpenOracle(oracleAddress).getPrice(approvedOracleSource,key);
    }  

    function oracle_getExpiry(string memory key) public view returns (uint64) {
    	uint64 timestamp = OpenOracle(oracleAddress).getTime(approvedOracleSource,key);
    	uint64 expiry = uint64(_maxOraclePriceAge[msg.sender]) + timestamp;
    	require(expiry >= timestamp, "uint64: addition overflow");
    	return expiry;
    }  

}

library SafeMath {
  function div(uint a, uint b) internal pure returns (uint) {
      require(b > 0, "SafeMath: division by zero");
      return a / b;
  }
  function mul(uint a, uint b) internal pure returns (uint) {
    if (a == 0) return 0;
    uint c = a * b;
    require (c / a == b, "SafeMath: multiplication overflow");
    return c;
  }
  function sub(uint a, uint b) internal pure returns (uint) {
    require(b <= a, "SafeMath: subtraction underflow");
    return a - b;
  }
  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a, "SafeMath: addition overflow");
    return c;
  }
}

abstract contract GovernanceToken {
    function totalSupply() public view virtual returns (uint256);
    function balanceOf(address _owner) public view virtual returns (uint256);
    function mint(address tgtAdd, uint amount) public virtual;
    function revoke(address tgtAdd, uint amount) public virtual;
    function setGovernance(address newGovernanceAddress) public virtual;
}

abstract contract OptionPool {
    function setGovernance(address newGovernanceContract) public virtual;
    function haltPool() public virtual;
    function freezePool() public virtual;
}

abstract contract OpenOracle {
    function getPrice(address a, string memory k) public virtual view returns (uint64);
    function getTime(address a, string memory k) public virtual view returns (uint64);
}

// SPDX-License-Identifier: None
