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
        socket_t sock;
        socket_t fd;
        socket_t fdAccept;
        uint8_t readLen = 0;
        uint8_t commandLen = 0;
        uint8_t buff[SOCKET_BUFFER_SIZE];

        uint8_t i;
       
        dbg(TRANSPORT_CHANNEL, "Server Timer started\n");       
       
        // for(i = 0; i < call connections.size(); i++) {
        //     fd = call connections.get(i);
        //     sock = call Transport.newlyEstablished();

        //     if(sock.state == LISTEN){
        //         fdAccept = call Transport.accept(fd);
        //     }
        // }

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

            if(call Transport.bind(sock, &sockAddr) == SUCCESS) {
                dbg(TRANSPORT_CHANNEL, "Socket %d has successfully binded to address: %d, port: %d\n", sock, sockAddr.addr, sockAddr.port);
                
                if(call Transport.listen(sock) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Socket %d is now in LISTEN state\n", sock);

                    call connections.pushback(sock); // this socket is part of server connections 

                    if(!serverTimerisRunning) {
                        // call serverTimer.startPeriodic(500); // 500 is just a random number

                        return SUCCESS;
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

                    write = call Transport.write(sock, buff, strlen((char*)buff));
                    sprintf(buff, "Hello %s%c%c%c%c%c\n", (char*)username, 92, 114, 92, 110, '\0'); // /r/n 
                    // 92 = /
                    // 114 = r
                    // 110 = n
                }
            }
            return SUCCESS;
        }
        
        dbg(TRANSPORT_CHANNEL, "Error! Socket %d connection failed", sock);
        return FAIL;
    }

    command error_t Chat.broadcast(uint8_t* message) {
        uint8_t write;
        char msg[SOCKET_BUFFER_SIZE];
        
        write = call Transport.write(client, msg, strlen((char*)msg));
        dbg(TRANSPORT_CHANNEL, "msg %s%c%c%c%c%c\n", (char*)message, 92, 114, 92, 110, '\0');
    }

    command error_t Chat.unicast(uint8_t* username, uint8_t* message) {
        uint8_t write;
        char msg[SOCKET_BUFFER_SIZE];

        write = call Transport.write(client, msg, strlen((char*)msg));
        dbg(TRANSPORT_CHANNEL, "To client %s msg %s%c%c%c%c%c\n", (char*)username, (char*)message, 92, 114, 92, 110,'\0');
    }

}