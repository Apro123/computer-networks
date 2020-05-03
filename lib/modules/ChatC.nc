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
    // components ActiveMessageC;
    // ChatP.Packet -> ActiveMessageC;
    components new SimpleSendC(AM_PACK);
    ChatP.Sender -> SimpleSendC;

    // components ActiveMessageC;
    // ChatP.Packet -> ActiveMessageC;

    components TransportC;
    ChatP.Transport->TransportC;

    components new TimerMilliC() as serverTimer;
    ChatP.nameTimer -> serverTimer;

    /* components new TimerMilliC() as clientTimer;
    ChatP.clientTimer -> clientTimer; */

    components new TimerMilliC() as readTimer;
    ChatP.readTimer -> readTimer;

    components RandomC as Random;
    ChatP.Random -> Random;

    /* components new ListC(socket_t, MAX_NUM_OF_SOCKETS) as connections;
    ChatP.connections -> connections; */

}
