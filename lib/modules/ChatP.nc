#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module ChatP {
    provides interface Chat;
    
    uses interface Packet;
    uses interface Transport;
    uses interface SimpleSend as Sender;

    uses interface Timer<TMilli> serverTimer;
    uses interface Timer<TMilli> clientTimer;
    uses interface List<socket_t> connections;

}

implementation {
    socket_t client; 
    buffer_t clientMessage;

    command error_t Chat.startChatServer(uint8_t port) { // starting server to get port41 and node id 1
        socket_t sock;
        socket_addr_t sockAddr;
    
        sockAddr.port = port; 
        sockAddr.addr = TOS_NODE_ID;
        sock = call Tranport.socket();
        
        serverTimerisRunning = call serverTimer.isRunning();

        if(sock != NULL) {
            dbg(TRANSPORT_CHANNEL, "This is socket %d\n", sock);

            if(call Transport.bind(sock, &address) = SUCCESS) {
                dbg(TRANSPORT_CHANNEL, "Socket %d has successfully binded to address: %d, port: %d\n", sock, sockAddr.addr, sockAddr.port);
                
                if(call Transport.listen(sock) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Socket %d is now in LISTEN state\n", sock);

                    call connections.pushback(sock); // this socket is part of server connections 

                    if(!serverTimerisRunning) {
                        call serverTimer.startPeriodic(500); // 500 is just a random number

                        return SUCCESS
                    }
                }
            }
        }
        
        return FAIL;
    }

}