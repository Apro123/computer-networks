#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"
#include "../../includes/socket.h"

configuration ChatC {
    provides interface Chat;
}

implementation {
    components ChatP;
    Chat = ChatP;

    components ActiveMessageC;
    ChatP.Packet->ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    TransportP.Sender->SimpleSendC;

    components new ListC(socket_t, MAX_NUM_OF_SOCKETS) as connections;
    ChatP.connections->connections;

    components new TimerMilliC() as serverTimer;
    ChatP.serverTimer->serverTimer;

    components new TimerMilliC() as clientTimer;
    ChatP.clientTimer->clientTimer;

}