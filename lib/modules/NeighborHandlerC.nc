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
}