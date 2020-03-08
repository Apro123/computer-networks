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

    components new AMReceiverC(AM_NEIGHBOR) as GeneralReceive;
    NeighborHandlerP.Receive -> GeneralReceive;

    components new SimpleSendC(AM_NEIGHBOR);
    NeighborHandlerP.Sender->SimpleSendC;

    components new TimerMilliC() as Timer1;
    NeighborHandlerP.neighborTimer -> Timer1;

    components new HashmapC(uint16_t, 19) as neighborCost;
    NeighborHandlerP.neighborCost->neighborCost;

    components new HashmapC(uint16_t, 19) as neighborwithCost;
    NeighborHandlerP.neighborWithCost->neighborwithCost;

    components RandomC as Random;
    NeighborHandlerP.Random -> Random;
}
