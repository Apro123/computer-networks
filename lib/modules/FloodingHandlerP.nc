#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingHandlerP {
  provides interface FloodingHandler;
  /* uses interface Receive; */
  uses interface Packet;
  uses interface SimpleSend as Sender;
  /* uses interface Hashmap<pack> as packetRecords; */
  // each node has its own instance of hashmap
  // hashmap key = dest, hashmap value = seq

  uses interface List<pack> as previousPackets;
}
implementation {

    /* Function returns SUCCESS if packet is not found in hashmap.  if it does exists then dont send it (returns FAIL). If it doesnt exist then send it and save and record the packet (SUCCESS)*/
    error_t checkPacketRecord(pack msg) {
      uint16_t i;

      for(i = 0; i < (call previousPackets.size()); i++) {
        uint16_t storedSrc;
      	uint16_t storedSeq;
      	uint8_t storedProtocol;
        pack temp;
        temp = (pack) call previousPackets.get(i);
        storedSrc = (uint16_t) temp.src;
        storedSeq = (uint16_t) temp.seq;
        storedProtocol = (uint16_t) temp.protocol;

        if(storedSeq == msg.seq && storedProtocol == msg.protocol && storedSrc == msg.src) {
          return FAIL;
        }
      }

      call previousPackets.pushback(msg);
      return SUCCESS;

      /* if(call packetRecords.contains(dest)) {
        uint16_t storedSrc;
      	uint16_t storedSeq;
      	uint8_t storedProtocol;
        pack temp;
        temp = call packetRecords.get(dest);
        storedSrc = temp.src;
        storedSeq = temp.seq;
        storedProtocol = temp.protocol;

        if(storedSeq == msg.seq && storedProtocol == msg.protocol && storedSrc == msg.src) {
          return FAIL;
        }
      }
      call packetRecords.insert(dest, msg);
      return SUCCESS; */
    }

    void printPackets(){

      uint16_t i;

      for(i = 0; i < (call previousPackets.size()); i++) {
        pack temp;
        temp = call previousPackets.get(i);
        logPack(&temp);
      }

      /* uint32_t* keys;
      uint8_t i;
      pack temp;

      keys = call packetRecords.getKeys();
      for(i = 0; i < call packetRecords.size(); i++) {
        temp = call packetRecords.get(keys[i]);
        dbg(FLOODING_CHANNEL, "key (dest): %d, value(pack)-> Src: %hhu Seq: %hhu Protocol:%hhu \n", keys[i], temp.src, temp.seq, temp.protocol);
      } */
    }

    command void FloodingHandler.flood(pack msg) {
      //check to see if packet exists already in hash map through the sequence number.
      error_t check;
      /* check = checkPacketRecord((uint32_t) msg.dest, msg); */
      check = checkPacketRecord(msg);
      if(SUCCESS == check) {
        dbg(FLOODING_CHANNEL, "Flooding packet\n");
        call Sender.send(msg, AM_BROADCAST_ADDR);
      } else {
        dbg(FLOODING_CHANNEL, "NOT Flooding same packet again\n");
      }

      printPackets();
    }
}
