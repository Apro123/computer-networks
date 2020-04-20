#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"
#include "../../includes/socket.h"

configuration ChatC {
    provides interface Chat;
}

implementation {
    components ChatP;
    Chat = ChatP;
}