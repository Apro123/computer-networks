#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module WindowP {
    provides interface Window;
    uses interface Packet;
    uses interface Transport;  
    uses interface Flooding;
    uses interface DistanceVector;
    
    uses interface Simplesend as Sender;
    uses interface Timer<TMilli> as timeout; //simple timer
    uses interface Timer<TMilli> as timeoutTimer;
    uses interface Timer<TMilli> as RTT;
    uses interface Timer<Tmilli> as closeTimer;
    uses interface List<socket_t> as window;
 

}

implementation {
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length);
    void makeTCPPack(tcpHeader *TCPPackage, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint16_t ack, uint8_t flag, uint8_t advertisedWindow, uint8_t data[TCP_PACKET_MAX_PAYLOAD_SIZE]);


    event void timeoutTimer.fired() {

    }    
    // socket_t socket;

//     command error_t Transport.connect() {
//         socket_t fd;
//         socket_store_t socket;
//         socket = call socket.get((uint32_t) fd);
//         tcp_pack tcpPack;

//         if (socket.state == CLOSED) {
//             status[fd].sentTime = call timeout.getNow();
//         }
//     }


void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint16_t length) {
    Package->src = src;
    Package->dest = dest;
    Package->TTL = TTL;
    Package->seq = seq;
    Package->Protocol = Protocol;
    memcpy(Package->Protocol, payload, length);
}

void makeTCPPack(tcpHeader *TCPPackage, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint16_t ack, uint8_t flag, uint8_t advertisedWindow, uint8_t data[TCP_PACKET_MAX_PAYLOAD_SIZE]) {
    TCPPackage->srcPort = srcPort;
    TCPPackage->destPort = destPort;
    TCPPackage->seq = seq;
    TCPPackage->ack = ack;
    TCPPackage->flag = flag;
    // TCPPackage->advertisedWindow = advertisedWindow;
    memcpy(TCPPackage->flag, advertisedWindow, data[TCP_PACKET_MAX_PAYLOAD_SIZE]);
}


} 
