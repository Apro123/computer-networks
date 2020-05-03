#include "../../includes/packet.h"
#include "../../includes/socket.h"

interface Chat {
    command void startChatServer(uint8_t port);
    command void startChatClient(uint8_t port, uint8_t* username);
    command void broadcast(uint8_t* message);
    command void unicast(uint8_t* username, uint8_t* message);
    command void handleCommand(uint8_t* cmd, uint8_t cmdSize, uint8_t* rest, uint8_t restSize, uint8_t* fullMsg);
    command void newConnection(socket_t newfd);
}
