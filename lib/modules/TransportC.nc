#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"
#include "../../includes/socket.h"

configuration TransportC {
  provides interface Transport;
}

implementation {
  components TransportP;
  Transport = TransportP;
  components ActiveMessageC;
  TransportP.Packet -> ActiveMessageC;

  components new SimpleSendC(AM_PACK);
  TransportP.Sender -> SimpleSendC;

  components new ListC(socket_t, MAX_NUM_OF_SOCKETS) as newEstaSock;
  TransportP.newEstaSock -> newEstaSock;

  components new ListC(socket_store_t, MAX_NUM_OF_SOCKETS) as sockets;
  TransportP.sockets -> sockets;
  //key is socket_t and value is socket_store_t

  components new TimerMilliC() as Timer1;
  TransportP.socketTimer -> Timer1;

  components RandomC as Random;
  TransportP.Random -> Random;

  components DistanceVectorC;
  TransportP.DistanceVector->DistanceVectorC;

  components FloodingHandlerC;
  TransportP.FloodingHandler -> FloodingHandlerC;

  components new TimerMilliC() as closeTimer;
  TransportP.closeTimer -> closeTimer;
}
