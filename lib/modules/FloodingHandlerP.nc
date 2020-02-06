#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingHandlerP {
  provides interface FloodingHandler;
  /* uses interface Receive; */
  uses interface Packet;
  uses interface Timer<TMilli> as sendPacketAgain;
  uses interface SimpleSend as Sender;
  uses interface Hashmap<uint16_t> as packetRecords;
  // each node has its own instance of hashmap
  // hashmap key = dest, hashmap value = seq
}
implementation {

    event void sendPacketAgain.fired() {
      dbg(FLOODING_CHANNEL, "sendPacketAgain fired\n");
    }

    /* error_t return success or fail
    if(SUCCESS == function())*/
    /* Function returns SUCCESS if packet is not found in hashmap.  if it does exists then dont send it (returns FAIL). If it doesnt exist then send it and save and record the packet (SUCCESS)*/
    error_t checkPacketRecord(uint32_t dest, uint16_t seq) {
      if(call packetRecords.contains(dest) && (call packetRecords.get(dest) == seq)) {
        return FAIL;
      } else {
        //no packet has ever been recieved with this dest before OR packet sequence number is not the samef
        call packetRecords.insert(dest, seq);
        return SUCCESS;
      }
    }

    void printHashTable(uint16_t dest){
      uint32_t* keys;
      uint8_t i;

      keys = call packetRecords.getKeys();
      for(i = 0; i < call packetRecords.size(); i++) {
        dbg(FLOODING_CHANNEL, "key: %d, value: %d\n", keys[i], call packetRecords.get(keys[i]));
      }
    }

    command void FloodingHandler.flood(pack msg) {

      /* call packetRecords.insert((uint32_t) dest, (uint16_t) msg.seq); */
      /* call packetRecords.insert(TOS_NODE_ID, dest); */

      //check to see if packet exists already in hash map through the sequence number.
      if(SUCCESS == checkPacketRecord((uint32_t) msg.dest, (uint16_t) msg.seq)) {
        dbg(FLOODING_CHANNEL, "Flooding packet\n");
        call Sender.send(msg, AM_BROADCAST_ADDR);
      } else {
        dbg(FLOODING_CHANNEL, "NOT Flooding same packet again\n");
      }

      dbg(FLOODING_CHANNEL, "node id: %d\n", TOS_NODE_ID);

      printHashTable(msg.dest);

      /* return FAIL; //FAIL or SUCCESS */
    }
}
