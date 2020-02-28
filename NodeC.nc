/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components FloodingHandlerC;
    Node.FloodingHandler -> FloodingHandlerC;

    components new TimerMilliC() as Timer0;
    Node.sendPacketAgain -> Timer0;

    components new ListC(pack, 32) as sentPackets;
    Node.sentPackets -> sentPackets;

    components new ListC(uint32_t, 32) as sentPacketsTime;
    Node.sentPacketsTime -> sentPacketsTime;

    components new ListC(uint8_t, 32) as sentPacketsTimesToSendAgain;
    Node.sentPacketsTimesToSendAgain -> sentPacketsTimesToSendAgain;

    components NeighborHandlerC;
    Node.NeighborHandler->NeighborHandlerC;
}
