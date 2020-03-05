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
    uses interface Hashmap<uint16_t> as neighborCost;
}

implementation{
    uint32_t INTERVAL_TIME = 2500;
    uint16_t sequence = 0;
    dvrPayload dvrPay;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length);

    task void sendVector() {
        pack temp;
        uint32_t now;
        bool isRunning;

        makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 1, 0, sequence, (uint8_t*)&dvrPay, sizeof(dvrPayload));

        isRunning = call sendTimer.isRunning();
        if(!isRunning) {
            now = call sendTimer.getNow();
            call sendTimer.startPeriodicAt(now-75, INTERVAL_TIME*12);
        }
        /* logPack(&temp); */
        call Sender.send(temp, AM_BROADCAST_ADDR);
        dbg(ROUTING_CHANNEL, "fweef\n");
        sequence = sequence + 1;
    }

    command void DistanceVector.runTimer() {
      post sendVector();
    }

    event void sendTimer.fired() {
      call sendTimer.startOneShot(INTERVAL_TIME-20);
    }

    command void DistanceVector.printRouteTable() {
      dbg(ROUTING_CHANNEL, "Printing route table for Node %d\n", TOS_NODE_ID);
      return;
    }

    command void DistanceVector.handleVectorReceive(pack* msg) {
      logPack(msg);
      return;
    }

    command void receiveHashmap(uint32_t* neighborWCost) {
        uint32_t i;
        // uint32_t* keys;
        uint16_t size;
        uint32_t nWC[255];
        uint32_t* keys;

        neighborCost = neighborWCost;
       
        size = call neighborCost.size();
        keys = neighborCost.getKeys();

        // for(i = 0; i < size; i++) {
            
        // }

        return;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint16_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);

   }

}
