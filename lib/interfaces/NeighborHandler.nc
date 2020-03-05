#include "../../includes/packet.h"

interface NeighborHandler {
    command void printNeighbors();
    command void runTimer();
    command void neighborHandlerReceive(pack* msg);
    command void NeighborsWithCost();
    // command Hashmap<uint16_t> NeighborsWithCost();
}
