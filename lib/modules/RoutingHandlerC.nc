#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration RoutingHandlerC {
    provides interface RoutingHandler;
}

implementation {
    components RoutingHandlerP;
    RoutingHandler = RoutingHandlerP;
}