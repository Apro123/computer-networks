#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborHandlerP {
    provides interface NeighborHandler

    uses interface Packet;
    uses interface SimpleSend as Sender;
    uses interface List<uint16_t> as neighborList;
    uses interface Timer<TMilli> as neighborTimer;
}

implementation {
    
    uint8_t TIMES_TO_SEND_PACKET = 3;

    void logPackNeighbor(pack *input) {
        dgb(NEIGHBOR_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    task void findNeighbors() {
        pack temp;
        uint32_t now; 
        bool isRunning;
        makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 1, 0, 0, (uint8_t*)"", PACKET_MAX_PAYLOAD);

        isRunning = call neighborTimer.isRunning();
        if(!isRunning) {
            now = call neighborTimer.getNow();
            call neighborTimer.startPeriodicAt(Now-100, INTERVAL_TIME*3);
        }

        call Sender.send(temp, AM_BROADCASE_ADDR);
        dbg(NEIGHBOR_CHANNEL, "NODE %d sending ping\n", TOS_NODE_ID);
    }
    
}