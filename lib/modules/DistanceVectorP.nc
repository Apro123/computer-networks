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
    uses interface Timer<TMilli> as tableTimer;
    uses interface Timer<TMilli> as dropRow;
    uses interface NeighborHandler as NeighborHandler;
    uses interface Random as Random;
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
    row toSend[5];
    uint8_t numRowToSend = 0;


    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length);

    void logPackDVR(pack *input) {
        dbg(ROUTING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    void getNeighborData() {
        uint32_t i;
        uint16_t size;
        uint8_t* neighborIDs;
        uint8_t* neighborCost;


        neighborIDs = call NeighborHandler.getKeys();
        neighborCost = call NeighborHandler.getCost();
        size = call NeighborHandler.getSize();


        if(currentSize == 0) {
          for(i = 0; i < size; i++) {
            routingTable[i].dest = neighborIDs[i];
            routingTable[i].nextHop = neighborIDs[i];
            routingTable[i].cost = neighborCost[i];
            routingTable[i].TTL = DV_TTL;

            currentSize += 1;
          }
        } else {
          //find the neighbors and update them
          for(i = 0; i < currentSize; i++) {
            uint8_t j;
            for(j = 0; j < size; j++) {
              //find the neighbor in the routing table and update the cost and the ids
              if(neighborIDs[j] == routingTable[i].dest) {
                routingTable[i].nextHop = neighborIDs[j];
                routingTable[i].cost = neighborCost[j];
                routingTable[i].TTL = DV_TTL; //need to be updated
                break;
              }
            }

          }
        }
        return;
    }

    void sendBatch(uint8_t num) {
      pack temp;
      uint8_t set[sizeof(row)*num];
      memcpy(set, toSend, sizeof(row)*num);
      makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, num, 5, sequence, set, sizeof(row)*num);
      call Sender.send(temp, AM_BROADCAST_ADDR);
    }

    void addRowToSend(row rowToSend) {
      toSend[numRowToSend] = rowToSend;
      numRowToSend += 1;
      if(numRowToSend == 5) {
        sendBatch(5);
        numRowToSend = 0;
      }
    }

    void sendTable() {
      uint8_t i = 0;

      for(i = 0; i < currentSize; i++) {
        row temp = routingTable[i];
        addRowToSend(temp);
      }
      sendBatch(numRowToSend); //send any remaining

    }

    task void sendVector() {
        sendTable();

        if(call tableTimer.isOneShot()) {
          call tableTimer.startPeriodic(500 + (uint16_t) (call Random.rand16()%200));
        }

        sequence = sequence + 1;
    }

    command void DistanceVector.runTimer() {
      call tableTimer.startOneShot(INTERVAL_TIME/4 - + (uint16_t) (call Random.rand16()%200));
      call dropRow.startPeriodic(INTERVAL_TIME*8 + (uint16_t) (call Random.rand16()%200));
    }

    event void tableTimer.fired() {
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

      dbg(ROUTING_CHANNEL, "current size: %d\n", currentSize);

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
        if(tempRow.cost == 255) {
          newCost = 255;
        }

        tempRow.nextHop = src;
        //for each row update the table
        for(j = 0; j < currentSize; ++j) {
          if(tempRow.dest == routingTable[j].dest) {
            exists = TRUE;
            /* if(TOS_NODE_ID == 3 && tempRow.dest == 6) {
              dbg(ROUTING_CHANNEL, "tempRow row-> dest: %d, hop, %d cost: %d\n", tempRow.dest, tempRow.nextHop, newCost);
            } */
            if(newCost < routingTable[j].cost) {
              //found a better route
              memcpy((routingTable+j), &tempRow, sizeof(row));
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
          /* if(TOS_NODE_ID == 3) {
            dbg(ROUTING_CHANNEL, "row-> dest: %d, hop, %d cost: %d\n", tempRow.dest, tempRow.nextHop, newCost);
          } */
          memcpy((routingTable+j), &tempRow, sizeof(row));
          /* routingTable[j] = tempRow; */
          routingTable[j].TTL = DV_TTL;
          routingTable[j].cost = newCost;
          currentSize += 1;

          /* if(TOS_NODE_ID == 3) {
            call DistanceVector.printRouteTable();
          } */
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

          updateTable((row*) myMsg->payload, myMsg->TTL, link, src);

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
