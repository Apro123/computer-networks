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

    command error_t Chat.startChatClient(uint8_t port, uint8_t* username) {
        socket_t sock;
        socket_addr_t srcAddr;
        socket_addr_t destAddr; 
        uint8_t buff[SOCKET_BUFFER_SIZE];
        sock = call Transport.socket();

        srcAddr.port = port;
        srcAddr.addr = TOS_NODE_ID;

        destAddr.port = 41; // connect to port 41
        destAddr.addr= 1; // node 1

        if(sock != NULL) {

            dbg(TRANSPORT_CHANNEL, "This is socket %d\n", sock);

            if (call Transport.bind(sock, &srcAddr) == SUCCESS) {
                
                dbg(TRANSPORT_CHANNEL, "Socket %d has binded to address: %d, port: %d\n", sock, srcAddr.addr, srcAddr.port);
                dbg(TRANSPORT_CHANNEL, "Attempting to connect to server with port %d at address %d\n", destAddr.port, destAddr.addr);

                if(call Transport.connect(sock, &srcAddr) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Socket %d connected succesfully\n", sock);
                }


            }
        }

    }

}