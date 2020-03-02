#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module RoutingHandlerP {
    provides interface RoutingHandler;

    uses interface packet;
    uses interface SimpleSend as Sender;
    uses interface List<uint16_t> as routingList;
}

implementation {
    
}