#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module ChatP {
    provides interface Chat;
    // uses interface Packet;
    uses interface SimpleSend as Sender;
    
    uses interface Transport; 

    uses interface Timer<TMilli> as serverTimer;
    uses interface Timer<TMilli> as clientTimer;
    uses interface List<socket_t> as connections;

}

implementation {
    socket_t client; 
    // buffer_t clientMessage;


    event void serverTimer.fired() {
        dbg(TRANSPORT_CHANNEL, "Server Timer started");
    }

    event void clientTimer.fired() {
        dbg(TRANSPORT_CHANNEL, "Client Timer Started");
    }

    command error_t Chat.startChatServer(uint8_t port) {
        socket_t sock;
        socket_addr_t sockAddr;
        bool serverTimerisRunning;
    
        sockAddr.port = port; 
        sockAddr.addr = TOS_NODE_ID;
        sock = call Transport.socket();
        
        serverTimerisRunning = call serverTimer.isRunning();

        if(call Transport.socket() != NULL) {
            dbg(TRANSPORT_CHANNEL, "This is socket %d\n", sock);

            if(call Transport.bind(sock, &sockAddr) = SUCCESS) {
                dbg(TRANSPORT_CHANNEL, "Socket %d has successfully binded to address: %d, port: %d\n", sock, sockAddr.addr, sockAddr.port);
                
                if(call Transport.listen(sock) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Socket %d is now in LISTEN state\n", sock);

                    call connections.pushback(sock); // this socket is part of server connections 

                    if(!serverTimerisRunning) {
                        // call serverTimer.startPeriodic(500); // 500 is just a random number

                        return SUCCESS
                    }
                }
            }
        }
        
        return FAIL;
    }

    command error_t Chat.startChatClient(uint8_t port, uint8_t* username) { //start chat client and try to connect to port 41 and node 1
        socket_t sock;
        socket_addr_t srcAddr;
        socket_addr_t destAddr; 
        uint8_t buff[SOCKET_BUFFER_SIZE];
        uint8_t write;
        sock = call Transport.socket();

        srcAddr.port = port;
        srcAddr.addr = TOS_NODE_ID;

        destAddr.port = 41; // connect to port 41
        destAddr.addr= 1; // node 1

        if(call Transport.socket() != NULL) {

            dbg(TRANSPORT_CHANNEL, "This is socket %d\n", sock);

            if (call Transport.bind(sock, &srcAddr) == SUCCESS) {
                
                dbg(TRANSPORT_CHANNEL, "Socket %d has binded to address: %d, port: %d\n", sock, srcAddr.addr, srcAddr.port);
                dbg(TRANSPORT_CHANNEL, "Attempting to connect to server with port %d at address %d\n", destAddr.port, destAddr.addr);

                if(call Transport.connect(sock, &srcAddr) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Socket %d connected succesfully\n", sock);

                    write = call Transport.write(sock, buff, (char*)buff);

                }
            }
            return SUCCESS;
        }
        
        dbg(TRANSPORT_CHANNEL, "Error! Socket %d connection failed", sock);
        return FAIL;

    }

}