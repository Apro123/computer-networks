#include "../../includes/packet.h"

interface NeighborHandler {
    command void printNeighbors();
    command void runTimer();
    command void neighborHandlerReceive(pack* msg);
    command void calculateNeighborsWithCost();
    command uint32_t* getKeys();
    command uint16_t* getCost();
    command uint16_t getSize();
}
