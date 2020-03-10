#include "../../includes/packet.h"

interface DistanceVector {
    command void runTimer();
    command void printRouteTable();
    command uint16_t getNextHop(pack pk);
}
