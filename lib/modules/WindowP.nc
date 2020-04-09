#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module WindowP {
    provides interface Window;
    uses interface packet;
    uses interface Simplesend as Sender;
    uses interface Timer<TMilli> as timeout; //simple timer
    uses interface Timer<TMilli> as RTT;
    uses interface List<socket_t> as windowPack;
    uses interface Transport;

}

implementation {
    socket_t socket;

    command error_t Transport.connect() {
        socket_t fd;
        socket_store_t socket;
        socket = call socket.get((uint32_t) fd);
        tcp_pack tcpPack;

        if (socket.state == CLOSED) {
            status[fd].sentTime = call timeout.getNow();
        }
    }
} 
