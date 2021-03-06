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
    uses interface Receive;
    uses interface SimpleSend as Sender;
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Hashmap<uint16_t> as neighborCost;
    uses interface Hashmap<uint16_t> as neighborWithCost;
    uses interface Random as Random;
    //key is the neighbor, value is how many times packet has been recieved from neighbor
    //when printing the neighbors, the cost is calculated
}

implementation{
    uint32_t INTERVAL_TIME = 2500;
    uint16_t TimesSent = 0;
    uint8_t keys[255];
    uint8_t costs[255];
    uint8_t size;

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
            call neighborTimer.startPeriodicAt(now-100, INTERVAL_TIME*8 + (uint16_t) (call Random.rand16()%200));
        }

        call Sender.send(temp, AM_BROADCAST_ADDR);
        dbg(NEIGHBOR_CHANNEL, "NODE %d sending ping\n", TOS_NODE_ID);
        TimesSent = TimesSent + 1;
    }

    event void neighborTimer.fired() {
      post findNeighbors(); //calling task from previous method
   }
   command void NeighborHandler.runTimer() {
       call neighborTimer.startOneShot(10 + (uint16_t) (call Random.rand16()%200));
   }
    command void NeighborHandler.printNeighbors(){
        uint32_t i;
        uint32_t* tempKeys;
        uint16_t tempSize;

        dbg(NEIGHBOR_CHANNEL, "Neighbors of Node %d below\n", TOS_NODE_ID);
        tempKeys = call neighborCost.getKeys();
        tempSize = call neighborCost.size();
        for(i = 0; i < tempSize; i++) {
          dbg(NEIGHBOR_CHANNEL, "times received: %d\n", call neighborCost.get(tempKeys[i]));
          dbg(NEIGHBOR_CHANNEL, "times sent: %d\n", TimesSent);
          dbg(NEIGHBOR_CHANNEL, "NODE: %d, Cost: %d\n", tempKeys[i], (TimesSent/call neighborCost.get(tempKeys[i])));

        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

       if(len==sizeof(pack)){
          pack* myMsg =(pack*) payload;
          bool exists;

          //if the packet is not for this node, then skip
          if(myMsg->protocol == 0 || myMsg->dest == TOS_NODE_ID) {

            exists = call neighborCost.contains(myMsg->src);
            if(!exists && myMsg->protocol == 1) {
              // it doesnt exist add it to the hashmap
              call neighborCost.insert(myMsg->src, 1);
            } else if(myMsg->protocol == 1 && myMsg->dest == TOS_NODE_ID) {
              //if protocol is ping reply and the packet is meant for this node then increase the times received
              uint16_t timesReceived = call neighborCost.get(myMsg->src);
              timesReceived += 1;
              call neighborCost.insert(myMsg->src, timesReceived);

            } else if(myMsg->protocol == 0) {
              pack reply;
              makePack(&reply, TOS_NODE_ID, myMsg->src, 1, 1, 0, (uint8_t*)"", PACKET_MAX_PAYLOAD_SIZE);
              call Sender.send(reply, AM_BROADCAST_ADDR);
            }
          }


          return msg;
       }

       dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
       return msg;
    }

    /* command void NeighborHandler.neighborHandlerReceive(pack* msg){
        bool exists;

        logPackNeighbor(msg);
        dbg(NEIGHBOR_CHANNEL, "Packet Received\n");
        dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERED\n");

        exists = call neighborCost.contains(msg->src);

        if(!exists && msg->protocol == 1) {
          call neighborCost.insert(msg->src, 1);
        } else if(msg->protocol == 1 && TOS_NODE_ID == msg->seq){

          uint16_t cost = call neighborCost.get(msg->src);
          cost = cost + 1;
          call neighborCost.insert(msg->src, cost);
        }
        if(msg->protocol == 0) {
          pack neighborPingReply;
          makePack(&neighborPingReply, TOS_NODE_ID, TOS_NODE_ID, 1, 1, msg->src, (uint8_t*)"", PACKET_MAX_PAYLOAD_SIZE);
          call Sender.send(neighborPingReply, AM_BROADCAST_ADDR);
        }
    } */

   command void NeighborHandler.calculateNeighborsWithCost() {
     uint32_t i;
     uint32_t* tempKeys;
     uint16_t tempSize;

     tempKeys = call neighborCost.getKeys();
     tempSize = call neighborCost.size();
     for(i = 0; i < tempSize; i++) {
       keys[i] = (uint8_t) tempKeys[i];
       /* memcpy(costs[i], call neighborCost.get(keys[i]) / TimesSent, sizeof()) */
       costs[i] = (uint8_t) TimesSent/(call neighborCost.get(keys[i]));
       /* call neighborWithCost.insert(keys[i], call neighborCost.get(keys[i]) / TimesSent); */
     }
     /* call neighborWithCost.insert(TOS_NODE_ID, 0); //did this so we the current neighbor can tell itself it has the cost of 0 */
     keys[tempSize] = TOS_NODE_ID;
     costs[tempSize] = 0;
     size = (uint8_t) tempSize+1;
     /* keys = call neighborWithCost.getKeys();
     size = call neighborWithCost.size();
     for(i = 0; i < size; i++) {
       costs[i] = call neighborWithCost.get(keys[i]);
     } */
   }

   command uint8_t* NeighborHandler.getKeys() {
    return keys;
   }

   command uint8_t* NeighborHandler.getCost() {
     return costs;
   }

    command uint8_t NeighborHandler.getSize() {
      return size;
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
