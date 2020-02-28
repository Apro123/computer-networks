#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module NeighborHandlerP {
    provides interface NeighborHandler;

    uses interface Packet;
    uses interface SimpleSend as Sender;
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Hashmap<uint16_t> as neighborCost;
    //key is the neighbor, value is how many times packet has been recieved from neighbor
    //when printing the neighbors, the cost is calculated
}

implementation{
    uint32_t INTERVAL_TIME = 2500;
    uint16_t TimesSent = 0;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    void logPackNeighbor(pack *input) {
        dbg(NEIGHBOR_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    task void findNeighbors() {
        pack temp;
        uint32_t now;
        bool isRunning;
        makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 1, 0, 0, (uint8_t*)"", PACKET_MAX_PAYLOAD_SIZE);

        isRunning = call neighborTimer.isRunning();
        if(!isRunning) {
            now = call neighborTimer.getNow();
            call neighborTimer.startPeriodicAt(now-100, INTERVAL_TIME*3);
        }

        call Sender.send(temp, AM_BROADCAST_ADDR);
        dbg(NEIGHBOR_CHANNEL, "NODE %d sending ping\n", TOS_NODE_ID);
        TimesSent = TimesSent + 1;
    }

    event void neighborTimer.fired() {
      post findNeighbors(); //calling task from previous method
   }
   command void NeighborHandler.runTimer() {
       call neighborTimer.startOneShot(10);
   }
    command void NeighborHandler.printNeighbors(){
        uint32_t i;
        uint32_t* keys;
        uint16_t size;

        dbg(NEIGHBOR_CHANNEL, "Neighbors of Node %d below\n", TOS_NODE_ID);
        keys = call neighborCost.getKeys();
        size = call neighborCost.size();
        for(i = 0; i < size; i++) {
          dbg(NEIGHBOR_CHANNEL, "NODE: %d, Cost: %d\n", keys[i], (call neighborCost.get(keys[i]))/TimesSent);

        }
    }

    command void NeighborHandler.neighborHandlerReceive(pack* msg){
        /* uint8_t i; */
        /* uint16_t size; */
        bool exists;
        logPackNeighbor(msg);
        dbg(NEIGHBOR_CHANNEL, "Packet Received\n");
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERED\n");

        exists = call neighborCost.contains(msg->src);

        if(!exists && msg->protocol == 1) {
          call neighborCost.insert(msg->src, 1);
        } else if(msg->protocol == 1){

          uint16_t cost = call neighborCost.get(msg->src);
          cost = cost + 1;
          call neighborCost.insert(msg->src, cost);
        }
        if(msg->protocol == 0) {
          pack neighborPingReply;
          makePack(&neighborPingReply, TOS_NODE_ID, TOS_NODE_ID, 1, 1, 0, (uint8_t*)"", PACKET_MAX_PAYLOAD_SIZE);
          call Sender.send(neighborPingReply, AM_BROADCAST_ADDR);
        }
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
