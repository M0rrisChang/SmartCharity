import "./BasicToken.sol";

contract Donation is BasicToken {
    event Love(address indexed to, uint amount);

    constructor(
    ) public {
        name = 'Smart Charity';
        symbol = 'SC';
    }
    
    function init(address yesser, address noer) public {
        balances[yesser] = 51;
        balances[noer] = 49;
    }

    function donate(address _tokenHolder) public payable returns (bool success) {
        require(msg.value > 0);

        balances[_tokenHolder] += msg.value;
        totalSupply += msg.value;
        emit Love(_tokenHolder, msg.value);
        return true;
    }
}
