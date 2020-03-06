#include "../../includes/packet.h"

interface NeighborHandler {
    command void printNeighbors();
    command void runTimer();
    /* command void neighborHandlerReceive(pack* msg); */
    command void calculateNeighborsWithCost();
    command uint8_t* getKeys();
    command uint8_t* getCost();
    command uint8_t getSize();
}
