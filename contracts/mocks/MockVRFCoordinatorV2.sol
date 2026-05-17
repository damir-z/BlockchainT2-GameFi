// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVRFConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockVRFCoordinatorV2 {
    uint256 public nextRequestId = 1;
    mapping(uint256 => address) public consumers;

    event RandomWordsRequested(uint256 indexed requestId, address indexed consumer);
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 randomWord);

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32 numWords
    ) external returns (uint256 requestId) {
        require(numWords == 1, "MockVRF: only one word");
        requestId = nextRequestId++;
        consumers[requestId] = msg.sender;
        emit RandomWordsRequested(requestId, msg.sender);
    }

    function fulfill(uint256 requestId, uint256 randomWord) external {
        address consumer = consumers[requestId];
        require(consumer != address(0), "MockVRF: unknown request");
        delete consumers[requestId];
        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;
        IVRFConsumer(consumer).rawFulfillRandomWords(requestId, words);
        emit RandomWordsFulfilled(requestId, randomWord);
    }
}
