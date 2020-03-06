#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"

configuration FloodingHandlerC {
  provides interface FloodingHandler;
}

implementation {
  components FloodingHandlerP;
  FloodingHandler = FloodingHandlerP;
  components ActiveMessageC;
  FloodingHandlerP.Packet -> ActiveMessageC;

  components new SimpleSendC(AM_PACK);
  FloodingHandlerP.Sender -> SimpleSendC;

  components new ListC(pack, 32) as previousPackets;
  FloodingHandlerP.previousPackets -> previousPackets;

  components new ListC(uint32_t, 32) as packetArrivalTimes;
  FloodingHandlerP.packetArrivalTimes -> packetArrivalTimes;

  components new TimerMilliC() as Timer1;
  FloodingHandlerP.dropPacket -> Timer1;
}
