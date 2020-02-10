#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module FloodingHandlerP {
  provides interface FloodingHandler;
  uses interface Packet;
  uses interface SimpleSend as Sender;

  uses interface List<pack> as previousPackets;
  uses interface List<uint32_t> as packetArrivalTimes;

  uses interface Timer<TMilli> as dropPacket;

  //timer is set to a set interval
  //every interval all packets whos "life expectancy" is at least 75% is dropped. 75 is an arbitrary number
  //this avoids packets from being stored in memory too long
  //for certain rare topopologies this may fail as this node may transmit the same package but that is okay because TTL will decrement and the packet will eventually die.
}
implementation {
    uint32_t INTERVAL_TIME = 2500; // same time as when the packet is sent

    void printPacketFlooding(pack *input) {
      dbg(FLOODING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n", input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
    }

    event void dropPacket.fired(){
      bool isEmpty;
      isEmpty = call previousPackets.isEmpty();

      if(!isEmpty) {
        pack temp;
        uint32_t packetTempNow;
        uint32_t baseTime;
        uint32_t intervalTime;
        uint8_t numPackets;
        dbg(FLOODING_CHANNEL, "dropping packet(s) below (timer fired)\n");
        //droppping packets whos life expectancy is more than 75%

        numPackets = call packetArrivalTimes.size(); //max list size or packet record size

        while(numPackets > 0) {
          packetTempNow = call packetArrivalTimes.front();
          baseTime = call dropPacket.gett0();
          intervalTime = call dropPacket.getdt();
          if(((packetTempNow - baseTime)*100)/intervalTime > 75) {
            temp = call previousPackets.popfront();
            call packetArrivalTimes.popfront();
            printPacketFlooding(&temp);
          }
          else {
            break;
          }
          numPackets--;
        }
      } else {
        dbg(FLOODING_CHANNEL, "Stopping dropPacket timer because list is empty\n");
        call dropPacket.stop();
      }
    }

    /* Function returns SUCCESS if packet is not found in hashmap.  if it does exists then dont send it (returns FAIL). If it doesnt exist then send it and save and record the packet (SUCCESS)*/
    error_t checkPacketRecord(pack msg) {
      uint16_t i;
      bool isRunning;
      uint32_t timeNow;

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
          /* printPacketFlooding(&temp); */
          return FAIL;
        }
      }

      isRunning = call dropPacket.isRunning();
      //only start timer if the timer is stopped aka the packet records list is empty
      if(!isRunning) {
        call dropPacket.startPeriodic( INTERVAL_TIME );
      }
      //get time now
      timeNow = call dropPacket.getNow();

      call previousPackets.pushback(msg);
      call packetArrivalTimes.pushback(timeNow);
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
