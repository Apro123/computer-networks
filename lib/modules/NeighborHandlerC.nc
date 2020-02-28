#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration NeighborHandlerC {
    provides interface NeighborHandler;
}

implementation {
    components NeighborHandlerP;
    NeighborHandler = NeighborHandlerP;
    components ActiveMessageC;
    NeighborHandlerP.Packet->ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    NeighborHandlerP.Sender->SimpleSendC;

    components new TimerMilliC() as Timer1;
    NeighborHandlerP.neighborTimer -> Timer1;

    components new HashmapC(uint16_t, 19) as neighborCost;
    NeighborHandlerP.neighborCost->neighborCost;
}
