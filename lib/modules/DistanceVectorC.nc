#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration DistanceVectorC {
    provides interface DistanceVector;
}

implementation {
    components DistanceVectorP;
    DistanceVector = DistanceVectorP;
    components ActiveMessageC;
    DistanceVectorP.Packet->ActiveMessageC;

    components new SimpleSendC(AM_DVR);
    DistanceVectorP.Sender->SimpleSendC;

    components new TimerMilliC() as Timer1;
    DistanceVectorP.sendTImer -> Timer1;

    /* components new HashmapC(uint16_t, 19) as neighborCost;
    DistanceVectorP.neighborCost->neighborCost; */
}
