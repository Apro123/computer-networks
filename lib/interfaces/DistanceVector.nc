#include "../../includes/packet.h"

interface DistanceVector {
    command void runTimer();
    command void handleVectorReceive(pack* msg);
    
}
