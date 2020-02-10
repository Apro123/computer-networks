/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface FloodingHandler;
// Neighbor discovery
   uses interface List<uint16_t> as neighborList; // list for neighbors
   uses interface Timer<TMilli> as neighborTimer; // timer for neighbor

   uses interface List<uint32_t> as sentPacketsTime;
   uses interface List<pack> as sentPackets;
   uses interface List<uint8_t> as sentPacketsTimesToSendAgain;
   //things need to save: time sent, packet, num times to send packet again
   uses interface Timer<TMilli> as sendPacketAgain;
   //timer is set to a set interval
   //every interval all packets whos "life expectancy" is at least 100% is dropped. 100 is an arbitrary number
   //this avoids packets from being stored in memory too long. Also this number is higher than dropping packets by the FLoodingHandlerP, because it is better to send packets again after waiting some extra time instead of sending the same packet again prematurally.
   //for certain rare cases this may cause the network needing to run longer since a ping event may occur right after another one, amking the second one wait longer for the first time around only. For the second time around, as the first one is "completed" (as in ping reply recieved or the times to send the packet has reached zero), then the timer adapts to the second one.
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0; //sequence automatically resets to 0
<<<<<<< 02b3a9350b433b4512f8d287da2612e7806af94f
   uint8_t TIMES_TO_SEND_PACKET = 3;
   uint32_t INTERVAL_TIME = 2500; // This is an arbitiary number. It is also the same number as the timers in FloodingHandlerP so if you all of the timers should start periodically a the same interval
=======


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
>>>>>>> started added nodes in a list to look for neighbors

   task void Task() {
      pack temp;
      makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 1, 0, 0, "", PACKET_MAX_PAYLOAD_SIZE); //making a pack with TTL of 1
      call neighborTimer.startPeriodic(2500);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR); //Sending a packet to all nodes
      dbg(NEIGHBOR_CHANNEL, "This current node is %d\n", TOS_NODE_ID);
   }

   event void neighborTimer.fired() {
      dbg(NEIGHBOR_CHANNEL, "NeighborTimer fired\n");
      post Task(); //calling task from previous method

   }

   void removeSentPacket(uint16_t pos) {
     call sentPacketsTimesToSendAgain.remove(pos); ///remove for secific index
     call sentPackets.remove(pos);
     call sentPacketsTime.remove(pos);
   }

   void resetTimer() {
     uint32_t nextPackett0;
     uint16_t size;
     size = call sentPackets.size();
     if(size > 0) {
       nextPackett0 = call sentPacketsTime.front();
       call sendPacketAgain.startPeriodicAt(nextPackett0, INTERVAL_TIME);
     } else {
       call sendPacketAgain.stop();
     }
   }

   event void sendPacketAgain.fired() {
     uint8_t i;
     uint8_t ind;
     uint16_t size;
     uint8_t storedSentPacketTimesToSendAgain;
     pack temp;
     pack packetsToBeSent[32];
     ind = 0; //index to be used for the packetsToBeSent list

     dbg(GENERAL_CHANNEL, "sendPacketAgain fired.\n");

     //first on in the list always needs to send again
     storedSentPacketTimesToSendAgain = call sentPacketsTimesToSendAgain.front();
     storedSentPacketTimesToSendAgain--;
     call sentPacketsTimesToSendAgain.set(0,storedSentPacketTimesToSendAgain);

     temp = call sentPackets.front();
     if(storedSentPacketTimesToSendAgain <= 0) {
       dbg(GENERAL_CHANNEL, "Reached max times to send packet below\n");
       logPack(&temp);
       //remove entry from all lists
       removeSentPacket(0);
       resetTimer();
     } else {
       dbg(GENERAL_CHANNEL, "Flooding Below Packets\n");
       packetsToBeSent[ind] = temp;
       ind++;
     }



     //checking for any other packets to be sent
     size = call sentPackets.size();
     i = 1;

     while(i < size && size > 0) {
       //need to add interval to t0 for each one
       uint32_t t0;
       uint32_t now;
       uint8_t timesToSendPacket;
       t0 = call sentPacketsTime.get(i);
       now = call sendPacketAgain.getNow();
       if(now - t0 >= INTERVAL_TIME) {
         //longer than or equal to INTERVAL_TIME means send it again as the packet has been waiting to be sent for its set time
         temp = call sentPackets.get(i);
         timesToSendPacket = call sentPacketsTimesToSendAgain.get(i);
         if(timesToSendPacket <= 0) {
           removeSentPacket(i);
         } else {
           timesToSendPacket--;
           call sentPacketsTimesToSendAgain.set(i,timesToSendPacket); //decrement the temp packet times to send again
           call sentPacketsTime.set(i,now);  //set the t0 to the new time
           packetsToBeSent[ind] = temp;
           ind++;
         }
      }
      i++;
     }




     for(i=0; i < ind; i++) {
       logPack(&packetsToBeSent[i]);
       call FloodingHandler.flood(packetsToBeSent[i]);
     }
   }

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call neighborTimer.startPeriodic(2500);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");

      uint16_t i;
      uint16_t j;
      // dbg(GENERAL_CHANNEL, "Packet Received\n");
      dbg(NEIGHBOR_CHANNEL, "NODE %d RECEIVED PACKET\n", TOS_NODE_ID); //seeing which node is recieving packet

      call neighborList.pushback(TOS_NODE_ID);
      dbg(NEIGHBOR_CHANNEL, "NODE %d is being pushed back in list\n", TOS_NODE_ID);

      for (i = 0; i < call neighborList.size(); i++) {
         if (call neighborList.get(i) == TOS_NODE_ID) {
            // dbg(NEIGHBOR_CHANNEL, "REPEATED NODE %d\n", TOS_NODE_ID);
            continue;
         }
      }
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         uint8_t tempTTL;

         /* dbg(FLOODING_CHANNEL, "Received Packet below\n"); */
         tempTTL = myMsg->TTL;
         myMsg->TTL = tempTTL - 1; //decrement TTL
         logPack(myMsg);

         if(myMsg->TTL == 0 && myMsg->src == myMsg->dest) {
            dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERED\n");
         }

         if((uint32_t) myMsg->dest != (uint32_t) TOS_NODE_ID) {
           dbg(FLOODING_CHANNEL, "NOT Packet dest, so implementing flooding again\n");

           if(myMsg->TTL != 0) {
             //dont die
             call FloodingHandler.flood(*myMsg);
           } else {
             //die
             dbg(FLOODING_CHANNEL, "Packet died due to TTL \n");
           }


         } else {
           dbg(GENERAL_CHANNEL, "-----------------\n");
           //this is the destination node for the packet
           //need to send a ping reply unless it is already a ping reply
           if(myMsg->protocol == 0) {
             pack temp;
             //time to send ping reply
             dbg(GENERAL_CHANNEL, "PING REPLY EVENT \n");
             dbg(GENERAL_CHANNEL, "-----------------\n");

             /* sequence++; //increment the sequence number */

             makePack(&temp, myMsg->dest, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequence, (uint8_t*)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
             dbg(GENERAL_CHANNEL, "Sending Ping Reply Packet below\n");
             logPack(&temp);
             call FloodingHandler.flood(temp);

           } else if (myMsg->protocol == 1) {
             uint8_t i;
             uint16_t size;
             dbg(GENERAL_CHANNEL, "Ping Reply received for packet and resetting timer\n");
             dbg(GENERAL_CHANNEL, "-----------------\n");
             //REMOVE PACKET THAT WAS RECEIVED and reset timer to whatever
             size = call sentPackets.size();
             i = 0;
             while(i < size) {
               pack comparePack;
               comparePack = call sentPackets.get(i);
               if(comparePack.src == myMsg->dest && comparePack.dest == myMsg->src) {
                 removeSentPacket(i);
                 resetTimer();
                 break;
               }
               i++;
             }
           }
         }

         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      bool isRunning;
      uint32_t timeNow;
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
      logPack(&sendPackage);

      isRunning = call sendPacketAgain.isRunning();
      //only start timer if the timer is stopped aka no packets are being currently being sent again
      if(!isRunning) {
        call sendPacketAgain.startPeriodic( INTERVAL_TIME );
      }

      //add packet into the sentPackets lists
      call sentPackets.pushback(sendPackage);
      timeNow = call sendPacketAgain.getNow();
      call sentPacketsTime.pushback(timeNow);
      call sentPacketsTimesToSendAgain.pushback(TIMES_TO_SEND_PACKET);

      call FloodingHandler.flood(sendPackage);
      //Sender.send returns success if it sent. USELESS beacuse does not return anything if node there is not runtime in between sending

      //increment the sequence number
      sequence++;
   }

   event void CommandHandler.printNeighbors(){
      // dbg(NEIGHBOR_CHANNEL, "Node %d is the neighbor of \n", TOS_NODE_ID);
      // for (uint16_t i = 0; i < call neighborList.size(); i++) {
      //    dbg(NEIGHBOR_CHANNEL, "NODE %d\n", call neighborList.get(i));
      // }

      // call neighborTimer.startPeriodic(2500);

      dbg(NEIGHBOR_CHANNEL, "This is Node %d\n", TOS_NODE_ID);
   }

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
