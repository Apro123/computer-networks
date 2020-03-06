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
    uses interface Receive;
    uses interface SimpleSend as Sender;

    uses interface Timer<TMilli> as sendTimer;
    uses interface Hashmap<uint16_t> as neighborCost;
    uses interface NeighborHandler as NeighborHandler;
}

implementation{
    uint32_t INTERVAL_TIME = 2500;
    uint16_t sequence = 0;
    dvrPayload dvrPay;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length);

    void logPackDVR(pack *input) {
        dbg(ROUTING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    void getNeighborData() {
        uint32_t i;
        uint16_t size;
        uint8_t* temp1;
        uint8_t temp[255];
        uint8_t nextHop[255];
        uint8_t cost[255];
        /* dbg(ROUTING_CHANNEL, "FWEFWE"); */


        temp1 = call NeighborHandler.getKeys();
        size = call NeighborHandler.getSize();

        /* dbg(ROUTING_CHANNEL, "FWEFWE"); */


        if(TOS_NODE_ID == 5) {
          dbg(ROUTING_CHANNEL, "keys below. Size: %d\n", size);
          for(i = 0; i < size; i++) {
            dbg(ROUTING_CHANNEL, "%d\n", temp1[i]);
          }
        }
        return;
    }

    task void sendVector() {
        pack temp;
        uint32_t now;
        bool isRunning;

        makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 2, 5, sequence, (uint8_t*)"route", PACKET_MAX_PAYLOAD_SIZE);

        isRunning = call sendTimer.isRunning();
        if(!isRunning) {
            now = call sendTimer.getNow();
            call sendTimer.startPeriodicAt(now-75, INTERVAL_TIME*12);
        }
        /* logPack(&temp); */
        call Sender.send(temp, AM_BROADCAST_ADDR);
        sequence = sequence + 1;
    }

    command void DistanceVector.runTimer() {
      call sendTimer.startOneShot(1000);
    }

    event void sendTimer.fired() {
      call NeighborHandler.calculateNeighborsWithCost();
      /* dbg(ROUTING_CHANNEL, "FWEFWE"); */
      getNeighborData();
      post sendVector();
    }

    command void DistanceVector.printRouteTable() {
      dbg(ROUTING_CHANNEL, "Printing route table for Node %d\n", TOS_NODE_ID);
      return;
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

       if(len==sizeof(pack)){
          pack* myMsg=(pack*) payload;

          /* logPackDVR(myMsg); */

          return msg;
       }

       dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
       return msg;
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
