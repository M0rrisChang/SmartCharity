# SmartCharity
## Introduction
This project is modified from DAO and aimed to be applied on charity field.
Whenever donation is committed, donator can
- make a proposal to help any group that he/she wants to
- vote on others' proposal
- do nothing like what happens now in real world

When voting period is over, everyone has the right to execute any proposal.
The amount set in ```newProposal``` would be automatically sent to assigned address.

## Interface of Donation
```function donate(address _tokenHolder)```

Balance of ```_tokenHolder``` would be added by ```msg.value```

## Interface of Charity
### Make a proposal
```function newProposal(address _recipient, uint _amount, string memory _description, uint64 _debatingPeriod)```

Propose a new proposal by giving receiver's address, amount that this proposal needs, decription of the proposal and voting period.

Note that only Initiator of this Charity could make new Proposal.

It will emit an event which contains ```proposalID``` of the proposal.

### Vote
```function Vote(uint _proposalID)```

Anyone can vote on proposal indexed by ```_proposalID```. 

The more donation made, the more yea/nay weighs.

### Unvote
```function unVote(uint _proposalID)```

Unvote votes.

### Execute Proposal
```function executeProposal(uint _proposalID)```

Check whether proposal is ready to go.

