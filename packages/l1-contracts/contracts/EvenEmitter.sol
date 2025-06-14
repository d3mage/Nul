pragma solidity >=0.8.27;

// Messaging
import {IRegistry} from "@aztec/governance/interfaces/IRegistry.sol";
import {IInbox} from "@aztec/core/interfaces/messagebridge/IInbox.sol";
import {IOutbox} from "@aztec/core/interfaces/messagebridge/IOutbox.sol";
import {IRollup} from "@aztec/core/interfaces/IRollup.sol";
import {DataStructures} from "@aztec/core/libraries/DataStructures.sol";
import {Hash} from "@aztec/core/libraries/crypto/Hash.sol";

contract EvenEmitter {
    event ReceivedChange(address who);

    IRegistry public registry;
    bytes32 public l2Bridge;

    IRollup public rollup;
    IOutbox public outbox;
    IInbox public inbox;
    uint256 public rollupVersion;

    function initialize(address _registry, bytes32 _l2Bridge) external {
        registry = IRegistry(_registry);
        l2Bridge = _l2Bridge;

        rollup = IRollup(registry.getCanonicalRollup());
        outbox = rollup.getOutbox();
        inbox = rollup.getInbox();
        rollupVersion = rollup.getVersion();
    }

    function process(
        address _who,
        uint256 _l2BlockNumber,
        uint256 _leafIndex,
        bytes32[] calldata _path
    ) external {
        // The purpose of including the function selector is to make the message unique to that specific call. Note that
        // it has nothing to do with calling the function.
        DataStructures.L2ToL1Msg memory message = DataStructures.L2ToL1Msg({
            sender: DataStructures.L2Actor(l2Bridge, rollupVersion),
            recipient: DataStructures.L1Actor(address(this), block.chainid),
            content: Hash.sha256ToField(
                abi.encodeWithSignature(
                    "process(address)",
                    _who
                )
            )
        });

        outbox.consume(message, _l2BlockNumber, _leafIndex, _path);

        emit ReceivedChange(_who);
    }
}
