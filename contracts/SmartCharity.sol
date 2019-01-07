/*
This file is the MVP of Blockchain Charity modified from DAO.
source: https://github.com/slockit/DAO
*/

import "./Donation.sol";
pragma solidity ^0.5.2;


contract CharityInterface {
    // The minimum debate period that a generic proposal can have
    // 0 is set for demo
    uint constant minProposalDebatePeriod = 0;
    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    uint constant executeProposalPeriod = 10 days;

    // Initiator
    address public initiator;

    // Token contract
    Donation token;

    // Proposals to spend the Charity's ether
    Proposal[] public proposals;

    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        uint amount;
        // A plain text description of the proposal
        string description;
        // A unix timestamp, denoting the end of the voting period
        uint votingDeadline;
        // True if the proposal's votes have yet to be counted, otherwise False
        bool open;
        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        bool proposalPassed;
        // Number of Tokens in favor of the proposal
        uint yea;
        // Number of Tokens opposed to the proposal
        uint nay;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
    }

    /// @notice donate without getting tokens
    function() external payable;

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
    /// Charity and sets `_recipient` as the new Charity's Curator.
    /// @param _recipient Address of the recipient of the proposed transaction
    /// @param _amount Amount of wei to be sent with the proposed transaction
    /// @param _description String describing the proposal
    /// @param _debatingPeriod Time used for debating a proposal, at least 2
    /// weeks for a regular proposal, 10 days for new Curator proposal
    /// @return The proposal ID. Needed for voting on the proposal
    function newProposal(
        address _recipient,
        uint _amount,
        string memory _description,
        uint _debatingPeriod
    ) onlyInitiator public returns (uint _proposalID);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    function vote(uint _proposalID, bool _supportsProposal) public;

    /// @notice Checks whether proposal `_proposalID` with transaction data
    /// `_transactionData` has been voted for or rejected, and executes the
    /// transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @return Whether the proposed transaction has been executed or not
    function executeProposal(
        uint _proposalID,
    ) public payable returns (bool _success);

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        string description
    );
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result);
}

// The Charity contract itself
contract TheCharity is CharityInterface {
    modifier onlyTokenholders {
        require(token.balanceOf(msg.sender) != 0);
            _;
    }

    modifier onlyInitiator {
        require(msg.sender == initiator);
            _;
    }

    constructor(
        Donation _token
    ) public {
        token = _token;
        proposals.length = 1; // avoids a proposal with ID 0 because it is used
	initiator = msg.sender;
    }

    function() external payable {
    }

    function newProposal(
        address _recipient,
        uint _amount,
        string memory _description,
        uint64 _debatingPeriod
    ) onlyTokenholders public payable returns (uint _proposalID) {

        if (_debatingPeriod < minProposalDebatePeriod
            || _debatingPeriod > 8 weeks
            || msg.value < proposalDeposit
            || msg.sender == address(this) //to prevent a 51% attacker to convert the ether into deposit
        )
            revert();

        _proposalID = proposals.length++;
        Proposal storage p = proposals[_proposalID];
        p.recipient = _recipient;
        p.amount = _amount;
        p.description = _description;
        p.votingDeadline = now + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default

        emit ProposalAdded(
            _proposalID,
            _recipient,
            _amount,
            _description
        );
    }

    function vote(uint _proposalID, bool _supportsProposal) onlyTokenholders public {

        Proposal storage p = proposals[_proposalID];
        // Check if double vote
        unVote(_proposalID);

        if (_supportsProposal) {
            p.yea += token.balanceOf(msg.sender);
            p.votedYes[msg.sender] = true;
        } else {
            p.nay += token.balanceOf(msg.sender);
            p.votedNo[msg.sender] = true;
        }

        emit Voted(_proposalID, _supportsProposal, msg.sender);
    }

    function unVote(uint _proposalID) public {
        Proposal storage p = proposals[_proposalID];

        require(now < p.votingDeadline);

        if (p.votedYes[msg.sender]) {
            p.yea -= token.balanceOf(msg.sender);
            p.votedYes[msg.sender] = false;
        }

        if (p.votedNo[msg.sender]) {
            p.nay -= token.balanceOf(msg.sender);
            p.votedNo[msg.sender] = false;
        }
    }

    function executeProposal(
        uint _proposalID
    ) public returns (bool _success) {

        Proposal storage p = proposals[_proposalID];

        // If we are over deadline and waiting period, assert proposal is closed
        if (p.open && now > p.votingDeadline + executeProposalPeriod) {
            closeProposal(_proposalID);
            return false;
        }

        // Check if the proposal can be executed
        if (now < p.votingDeadline  // has the voting deadline arrived?
            // Have the votes been counted?
            || !p.open
            || p.proposalPassed // anyone trying to call us recursively?
        )
            revert();

        bool proposalCheck = true;

        if (p.amount > address(this).balance)
            proposalCheck = false;


        // Execute result
        if (p.yea > p.nay && proposalCheck) {
            // we are setting this here before the CALL() value transfer to
            // assure that in the case of a malicious recipient contract trying
            // to call executeProposal() recursively money can't be transferred
            // multiple times out of the Charity
            p.proposalPassed = true;

            // this call is as generic as any transaction. It sends all gas and
            // can do everything a transaction can do. It can be used to reenter
            // the Charity. The `p.proposalPassed` variable prevents the call from 
            // reaching this line again
            p.recipient.call.value(p.amount);

            _success = true;
        }

        closeProposal(_proposalID);

        // Initiate event
        emit ProposalTallied(_proposalID, _success);
    }

    function closeProposal(uint _proposalID) internal {
        Proposal storage p = proposals[_proposalID];
        if (p.open)
            sumOfProposalDeposits -= p.proposalDeposit;
        p.open = false;
    }
}
