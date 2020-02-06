#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration FloodingHandlerC {
  provides interface FloodingHandler;
}

implementation {
  components FloodingHandlerP;
  FloodingHandler = FloodingHandlerP;

  /* components new AMReceiverC(AM_PACK) as GeneralReceive;
  FloodingHandlerP.Recieve -> GeneralReceive; */

  components ActiveMessageC;
  FloodingHandlerP.Packet -> ActiveMessageC;

  components new SimpleSendC(AM_PACK);
  FloodingHandlerP.Sender -> SimpleSendC;
  //MAYBE make multiple instances of Simple Send because it is a generic component

  components new HashmapC(pack, 32) as packetRecords; //32 is the HASH_MAX_SIZE
  FloodingHandlerP.packetRecords -> packetRecords;

}
