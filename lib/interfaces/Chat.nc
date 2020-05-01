#include "../../includes/packet.h"
#include "../../includes/socket.h"

interface Chat {
    command error_t startChatServer(uint8_t port);
    command error_t startChatClient(uint8_t port, uint8_t* username);
}