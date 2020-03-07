#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define MAX_SIZE 255
#define DV_TTL 4

module DistanceVectorP {
    provides interface DistanceVector;

    uses interface Receive;
    uses interface SimpleSend as Sender;
    uses interface AMPacket;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Timer<TMilli> as dropRow;
    /* uses interface Hashmap<uint16_t> as routingTable; */
    uses interface NeighborHandler as NeighborHandler;
}

implementation{
    typedef struct {
      uint8_t dest;
      uint8_t nextHop;
      uint8_t cost;
      uint8_t TTL;
    } row;

    uint32_t INTERVAL_TIME = 2500;
    uint16_t sequence = 1;
    uint8_t nextHop[MAX_SIZE];
    uint8_t cost[MAX_SIZE];
    row routingTable[MAX_SIZE];
    uint8_t currentSize = 0;


    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length);

    void logPackDVR(pack *input) {
        dbg(ROUTING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    void getNeighborData() {
        uint32_t i;
        uint16_t size;
        uint8_t* neighborIDs;
        uint8_t* neighborCost;
        /* uint8_t nextHop[255];
        uint8_t cost[255]; */
        /* dbg(ROUTING_CHANNEL, "FWEFWE"); */


        neighborIDs = call NeighborHandler.getKeys();
        neighborCost = call NeighborHandler.getCost();
        size = call NeighborHandler.getSize();

        /* dbg(ROUTING_CHANNEL, "FWEFWE"); */


        /* dbg(ROUTING_CHANNEL, "keys below. Size: %d\n", size); */
        for(i = 0; i < size; i++) {
          routingTable[i].dest = neighborIDs[i];
          routingTable[i].nextHop = neighborIDs[i];
          routingTable[i].cost = neighborCost[i];
          routingTable[i].TTL = DV_TTL;

          currentSize += 1;
          /* dbg(ROUTING_CHANNEL, "Node: %d, Next Hop: %d, Cost: %d\n", neighborIDs[i], nextHop[neighborIDs[i]], cost[neighborIDs[i]]); */
        }
        return;
    }

    task void sendVector() {
        pack temp;
        uint32_t now;
        bool isRunning;
        uint8_t i;
        uint8_t set[currentSize];

        /* memcpy(dvrPay.payload_NextHop, (uint8_t*) nextHop, 255);
        memcpy(dvrPay.payload_TotalCost, (uint8_t*) cost, 255); */
        /* dvrPay->payload_NextHop = (uint8_t*) nextHop;
        dvrPay->payload_TotalCost = (uint8_t*) cost; */

        if(currentSize < 5) {
          memcpy(set, routingTable, sizeof(row)*currentSize);
          /* for(i = 0; i < currentSize; i++) {
            uint8_t hop = ((row*) set)[i].nextHop;
            uint8_t count = ((row*) set)[i].cost;
            if(hop != 0) {
              dbg(ROUTING_CHANNEL, "%d\t\t%d\t%d\n", ((row*) set)[i].dest, hop, count);
            }
          } */
          makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, currentSize, 5, sequence, set, sizeof(row)*currentSize);
          call Sender.send(temp, AM_BROADCAST_ADDR);
        } else {
          for(i = 0; i < currentSize/5; i++) {
            memcpy(set, routingTable, sizeof(row)*5);
            makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 5, 5, sequence, set, sizeof(row)*5);
            call Sender.send(temp, AM_BROADCAST_ADDR);
          }
          memcpy(set, routingTable, sizeof(row)*(currentSize%5));
          makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, currentSize%5, 5, sequence, set, sizeof(row)*currentSize%5);
          call Sender.send(temp, AM_BROADCAST_ADDR);
        }

        /* makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 2, 5, sequence, (uint8_t*)"route", PACKET_MAX_PAYLOAD_SIZE); */

        isRunning = call sendTimer.isRunning();
        if(!isRunning) {
            now = call sendTimer.getNow();
            call sendTimer.startPeriodicAt(now-75, INTERVAL_TIME*24);
        }

        // AM_BROADCAST_ADDR = 65535
        /* logPack(&temp); */
        /* call Sender.send(temp, AM_BROADCAST_ADDR); */
        sequence = sequence + 1;
    }

    command void DistanceVector.runTimer() {
      call sendTimer.startOneShot(INTERVAL_TIME/2);
      call dropRow.startPeriodic(INTERVAL_TIME*8);
    }

    event void sendTimer.fired() {
      call NeighborHandler.calculateNeighborsWithCost();
      getNeighborData();
      post sendVector();
    }

    event void dropRow.fired() {
      uint8_t i;
      uint8_t newSize = currentSize;
      for(i = 0; i < currentSize; i++) {
        if(i < newSize) {
          //drop the expired ones by making the cost infinite
          if(routingTable[i].TTL == 0) {
            routingTable[i].cost = 255;
          } else {
            //decrement TTL
            routingTable[i].TTL = routingTable[i].TTL - 1;
          }

        }
      }
    }

    command void DistanceVector.printRouteTable() {
      uint8_t i;
      dbg(ROUTING_CHANNEL, "Routing Table: \n");
      dbg(ROUTING_CHANNEL, "Dest\tHop\tCount\n");

      for(i = 0; i < currentSize; i++) {
        uint8_t hop = routingTable[i].nextHop;
        uint8_t count = routingTable[i].cost;
        if(hop != 0) {
          dbg(ROUTING_CHANNEL, "%d\t\t%d\t%d\n", routingTable[i].dest, hop, count);
        }
      }
    }

    void updateTable(row* set, uint16_t len, uint8_t linkCost, uint8_t src) {
      uint8_t i;
      for(i = 0; i < len; i++) {
        uint8_t j;
        bool exists = FALSE;
        row tempRow = set[i];
        uint8_t newCost = tempRow.cost + linkCost;
        tempRow.nextHop = src;
        //for each row update the table
        for(j = 0; j < currentSize; ++j) {
          if(tempRow.dest == routingTable[j].dest) {
            exists = TRUE;
            if(newCost < routingTable[j].cost) {
              //found a better route
              routingTable[j] = tempRow;
              routingTable[j].cost = newCost;
              break;
            } else if(tempRow.nextHop == routingTable[j].nextHop) {
              //update the new cost
              routingTable[j].cost = newCost;
              break;
            }
            routingTable[j].TTL = DV_TTL;
          }
        }
        if(!exists && j == currentSize) {
          //new node to add into the table
          routingTable[j] = tempRow;
          routingTable[j].TTL = DV_TTL;
          routingTable[j].cost = newCost;
          currentSize += 1;
        }

      }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

       if(len==sizeof(pack)){
          pack* myMsg=(pack*) payload;
          uint8_t i;
          uint8_t link = 255;
          uint8_t src = call AMPacket.source(msg);
          for(i = 0; i < currentSize; i++) {
            if(routingTable[i].dest == src) {
              link = routingTable[i].cost;
            }
          }
          /* if(TOS_NODE_ID == 5) {
            dbg(ROUTING_CHANNEL, "cost: %d\n", link);
          } */
          updateTable((row*) myMsg->payload, myMsg->TTL, link, src);

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
