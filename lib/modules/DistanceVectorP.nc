#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module DistanceVectorP {
    provides interface DistanceVector;

    uses interface Packet;
    uses interface SimpleSend as Sender;
    uses interface Timer<TMilli> as sendTimer;
}

implementation{
    uint32_t INTERVAL_TIME = 2500;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    command void DistanceVector.runTimer() {
      return;
    }

    event void sendTimer.fired() {
      return;
    }

    command void DistanceVector.printRouteTable() {
      dbg(ROUTING_CHANNEL, "Printing route table for Node %d\n", TOS_NODE_ID);
      return;
    }

    command void DistanceVector.handleVectorReceive(pack* msg) {
      return;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

}
