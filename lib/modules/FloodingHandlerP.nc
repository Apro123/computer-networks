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
  uses interface Timer<TMilli> as dropPacket;

  //TODO: two timers to drop packet
  //first one is set to 1000 whenever it is saved in the FIFO list.
  //if second packet comes then it goes to first timer while the remaining time of the first one goes to the second timer.
  //if another packet comes before first and second is finished. it talks to the second timer and asks whether the timer is more than 50%? done then it drops that packet
}
implementation {

    void printPacketFlooding(pack *input) {
      dbg(FLOODING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    event void dropPacket.fired(){
      pack temp;
      bool isEmpty;
      isEmpty = call previousPackets.isEmpty();
      if(!isEmpty) {
        dbg(FLOODING_CHANNEL, "dropping packet below (timer fired)\n");
        temp = call previousPackets.popfront();

        printPacketFlooding(&temp);
        /* dbg(FLOODING_CHANNEL, "%d\n", call dropPacket.getNow());
        dbg(FLOODING_CHANNEL, "%d\n", call dropPacket.gett0());
        dbg(FLOODING_CHANNEL, "%d\n", call dropPacket.getdt()); */
      } else {
        dbg(FLOODING_CHANNEL, "Stopping dropPacket timer because list is empty\n");
        call dropPacket.stop();
      }
    }

    /* Function returns SUCCESS if packet is not found in hashmap.  if it does exists then dont send it (returns FAIL). If it doesnt exist then send it and save and record the packet (SUCCESS)*/
    error_t checkPacketRecord(pack msg) {
      uint16_t i;

      //search for packet
      for(i = 0; i < (call previousPackets.size()); i++) {
        uint16_t storedSrc;
      	uint16_t storedSeq;
      	uint8_t storedProtocol;
        uint16_t storedDest;
        pack temp;
        temp = (pack) call previousPackets.get(i);
        storedSrc = (uint16_t) temp.src;
        storedSeq = (uint16_t) temp.seq;
        storedProtocol = (uint16_t) temp.protocol;
        storedDest = (uint16_t) temp.dest;

        if(storedSeq == msg.seq && storedProtocol == msg.protocol && storedSrc == msg.src && storedDest == msg.dest) {
          printPacketFlooding(&temp);
          return FAIL;
        }
      }

      call dropPacket.startPeriodic( 1500 );
      call previousPackets.pushback(msg);
      return SUCCESS;
    }

    void printPackets(){

      uint16_t i;

      dbg(FLOODING_CHANNEL, "Current Packets Saved: *****\n");
      
      for(i = 0; i < (call previousPackets.size()); i++) {
        pack temp;
        temp = call previousPackets.get(i);
        printPacketFlooding(&temp);
      }

      dbg(FLOODING_CHANNEL, "*****\n");

    }

    command void FloodingHandler.flood(pack msg) {
      //check to see if packet exists already in hash map through the sequence number.
      error_t check;
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
