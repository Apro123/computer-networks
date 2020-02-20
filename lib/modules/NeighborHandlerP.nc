#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborHandlerP {
    provides interface NeighborHandler

    uses interface Packet;
    uses interface SimpleSend as Sender;
    uses interface List<uint16_t> as neighborList;
    uses interface Timer<TMilli> as neighborTimer;
}

implementation {
    uint32_t time = 2500;

    
}