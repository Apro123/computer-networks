#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"

configuration DistanceVectorC {
    provides interface DistanceVector;
}

implementation {
    components DistanceVectorP;
    DistanceVector = DistanceVectorP;
    components ActiveMessageC;
    DistanceVectorP.AMPacket->ActiveMessageC;

    components new AMReceiverC(AM_DVR) as GeneralReceive;
    DistanceVectorP.Receive -> GeneralReceive;

    components new SimpleSendC(AM_DVR);
    DistanceVectorP.Sender->SimpleSendC;

    components new TimerMilliC() as Timer1;
    DistanceVectorP.sendTimer -> Timer1;

    components new TimerMilliC() as Timer0;
    DistanceVectorP.dropRow -> Timer0;

    /* components new HashmapC(uint16_t, 19) as neighborCost;
    DistanceVectorP.routingTable->neighborCost; */

    components NeighborHandlerC;
    DistanceVectorP.NeighborHandler->NeighborHandlerC;
}
