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
    uses interface List<uint16_t> as nextHop;
    uses interface List<uint16_t> as destination;
}
#define MAX_ROUTES 255

implementation {
   typedef struct {
        NodeAddr destination;
        NodeAddr nextHop;
        int cost;
        uint16_t ttl;
    } routing;

    int numRoutes = 0;
    Route routingTable[MAX_ROUTES];

    void mergeRoute(Route *new) {
        int i;

        for(i = 0; i < numRoutes; i++) {
            
        }
    }

}