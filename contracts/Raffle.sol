//SPDX-License-Identifier: MIT

//Raffle

// Enter the lottery (paying some amount)
// Pick a random winner (verifiably random)
// Winner to be selected every X minutes -> completly automated

// Chainlink Oracle -> Randomness, Automated Execution

pragma solidity 0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughEthEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/** @title A sample Raffle Contract
 * @author Bodek
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev This implements ChainLink VRF v2 and ChainLink Keepers */

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    } // uint256 0 = OPEN, 1 = CALCULATING
    /* State variables */
    uint256 private immutable i_entranceFee; // immutable = cheap gas price
    address payable[] private s_players; // in storage because we will be modifiy that, payable to pay a winner
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_lastTimeStamp;

    /* Lottery Variables */
    address private s_recentWinner;
    // uint256 private s_state; // pending,open,closed,calculating
    RaffleState private s_raffleState;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        address vrfCoordinatorV2, // contract address - so we need mocks to run it
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee; // immutable variable (cheaper)
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    /* Functions */
    function enterRaffle() public payable {
        // require (msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        } // revert with error (cheaper)
        s_players.push(payable(msg.sender)); // keep track all player who entered raffle

        // Events
        // Emit an event when we update a dynamic array or mapping
        // indexed or non indexed
        // Indexed parameters = topics
        // Indexed Parameters are searchable
        // Named evetns with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev CHAINLINK KEEPERS / This is the function that Chainlink Keeper nodes call
     * they look for the upKeepNeed to return true
     * following should be true in order to return true:
     * 1. our time interval should have passed
     * 2. The lottery should have at least 1 player, and have some ETH
     * 3. Subscription is funded with LINK
     * 4. The lottery should be in an "open" state
     */
    function checkUpkeep(
        bytes memory /* checkData */ // calldata not working with string so we need to change to memory
    )
        public
        override
        returns (
            bool upKeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upKeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        // (block.timestamp - last block timestamp) > interval
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        // externals function little bit cheaper then public
        // Request the random number
        // Once we get it, do something with it
        // 2 transaction process <- chainlink vrf - more safe then 1 transaction
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING; // no one can enter lottery
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gasLane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // s_players size 10
        // randomNumber 200
        // 202 % 10 ? whats doesnt divide evenly into 202?
        // 20 * 10 = 200
        // 2
        // 202 % 10 = 2 thats how modular function works
        uint256 indexOfWinner = randomWords[0] % s_players.length; // give us index of our winner
        address payable recentWinner = s_players[indexOfWinner]; // address from person who win
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = 0;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // require(success)
        if (!success) {
            revert Raffle__TransferFailed();
        }
        // Keep track of list of previous winners
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure functions */

    function getEntranceFee() public view returns (uint256) {
        // users can call that function to get entrance fee
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        // who is in players table
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
