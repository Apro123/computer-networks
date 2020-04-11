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
#include "includes/socket.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface FloodingHandler;

   uses interface NeighborHandler;

   uses interface List<uint32_t> as sentPacketsTime;
   uses interface List<pack> as sentPackets;
   uses interface List<uint8_t> as sentPacketsTimesToSendAgain;
   //things need to save: time sent, packet, num times to send packet again
   uses interface Timer<TMilli> as sendPacketAgain;

   uses interface DistanceVector;
   uses interface Random as Random;

   uses interface Transport;

   uses interface List<socket_t> as acceptedSockets;
   uses interface Timer<TMilli> as printSocketInfo;
   uses interface Timer<TMilli> as clientWrite;
   uses interface Timer<TMilli> as stopWait;
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0; //sequence automatically resets to 0
   uint8_t TIMES_TO_SEND_PACKET = 3;
   uint32_t INTERVAL_TIME = 2500; // This is an arbitiary number. It is also the same number as the timers in FloodingHandlerP so if you all of the timers should start periodically a the same interval
   socket_t fd;
   socket_addr_t sockAddr;
   socket_addr_t serAddrFromC;
   uint8_t bToTransfer; //0 to transfer
   uint8_t lastByteWritten;
   bool SERVER;
   uint8_t newEstaCheck;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void printSocketInfo.fired() {
     bool isRunning;
     uint16_t i;
     /* dbg(TRANSPORT_CHANNEL, "socket read info fired\n"); */
     isRunning = call printSocketInfo.isRunning();
     if(!isRunning) { //means new connection to accept
       socket_t* newfd;
       newfd = call Transport.getNewlyEstablished();
       if(newfd != NULL) {
         uint8_t j;
         uint8_t size;
         size = (uint8_t) newfd[0];
         for(j=0; j < size; j++) {
           dbg(TRANSPORT_CHANNEL, "adding socket_t : %d\n", newfd[j+1]);
           call acceptedSockets.pushback(newfd[j+1]);
         }
         /* call acceptedSockets.pushback(newfd); */
       }
     }
     return;
     for(i = 0; i < call acceptedSockets.size(); i++) {
       socket_t fd_temp;
       uint16_t buffSize;
       uint8_t* buff;
       uint16_t realdata[6];
       uint8_t j = 0;

       buff = (uint8_t*) 3654; //useless call to avoid compile warning

       fd_temp = call acceptedSockets.get(i);
       buffSize = (uint8_t) call Transport.read(fd_temp, buff, 12); //6 uint16_t words
       if(buffSize > 0) {
         for(j=0; j<buffSize/2; j++) {
           /* if(buffSize <= j*2) {
             realdata[j] = NULL;
           } else { */
          realdata[j] = ((uint16_t) buff[j*2]) | buff[j*2+1];
           /* } */
         }
         dbg(TRANSPORT_CHANNEL, "Reading data: %d,%s,%s,%s,%s", realdata[0], realdata[1] ? ""+ realdata[1]: " ", realdata[2] ? ""+ realdata[2]: " ", realdata[3] ? ""+ realdata[3]: " ", realdata[4] ? ""+ realdata[4]: " ");
       }

     }
   }

   event void clientWrite.fired() {
     /* dbg(TRANSPORT_CHANNEL, "client write fired\n"); */
     //if buffer is not empty and transfer is not done
   }

   event void stopWait.fired() {
     bool cont; //continue if connection is established
     cont = call Transport.isEstablished(fd);
     if(cont) {
       if(SERVER) {
         call printSocketInfo.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
       } else {
         call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
       }
     }
   }

   void removeSentPacket(uint16_t pos) {
     call sentPacketsTimesToSendAgain.remove(pos); ///remove for specific index
     call sentPackets.remove(pos);
     call sentPacketsTime.remove(pos);
   }

   void resetTimer() {
     uint32_t nextPackett0;
     uint16_t size;
     size = call sentPackets.size();
     if(size > 0) {
       nextPackett0 = call sentPacketsTime.front();
       call sendPacketAgain.startPeriodicAt(nextPackett0, INTERVAL_TIME+ (uint16_t) (call Random.rand16()%200));
     } else {
       call sendPacketAgain.stop();
     }
   }

   event void sendPacketAgain.fired() {
     //timer is set to a set interval
     //every interval all packets whos "life expectancy" is at least 100% is dropped. 100 is an arbitrary number
     //this avoids packets from being stored in memory too long. Also this number is higher than dropping packets by the FLoodingHandlerP, because it is better to send packets again after waiting some extra time instead of sending the same packet again prematurally.
     //for certain rare cases this may cause the network needing to run longer since a ping event may occur right after another one, amking the second one wait longer for the first time around only. For the second time around, as the first one is "completed" (as in ping reply recieved or the times to send the packet has reached zero), then the timer adapts to the second one.
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
       /* logPack(&packetsToBeSent[i]); */
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
         call NeighborHandler.runTimer();
         call DistanceVector.runTimer();
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         uint8_t tempTTL;

         //tcp packet
         if(myMsg->protocol == 4) {
           //TTL used to store number of data "items" (uint16_t size words)
           newEstaCheck = call Transport.receive(myMsg);
           //check if new socket connection, then stop the timer and signal printSocketInfo timer.fired() event to accept the connection
           if(newEstaCheck == 2) {
             dbg(TRANSPORT_CHANNEL, "CONNECTION ESTABLISHED\n");
             if(SERVER) {
               call printSocketInfo.stop();
               signal printSocketInfo.fired();
             } else {
               //client
               call stopWait.stop();
               call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
             }
           } else if (newEstaCheck == 3) {
             //server
             call stopWait.stop();
             call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200));
           }
           return msg;
         }


         tempTTL = myMsg->TTL;
         myMsg->TTL = tempTTL - 1; //decrement TTL


         //dest is not node id then continue to send it
         if((uint32_t) myMsg->dest != (uint32_t) TOS_NODE_ID) {
           dbg(GENERAL_CHANNEL, "Packet Received\n");
           logPack(myMsg);
           dbg(FLOODING_CHANNEL, "NOT Packet dest, so implementing flooding again\n");

           if(myMsg->TTL != 0) {
             //dont die
             uint16_t nextHop;
             nextHop = call DistanceVector.getNextHop(*myMsg);
             dbg(ROUTING_CHANNEL, "pack recieved, implementing dvr\n");
             if(nextHop == 256) {
               dbg(ROUTING_CHANNEL, "infinite cost or node not in table \n");
               call FloodingHandler.flood(*myMsg);
             } else {
               dbg(ROUTING_CHANNEL, "Sending to Node: %d\n", nextHop);
               call Sender.send(*myMsg, nextHop);
             }
             /* call FloodingHandler.flood(*myMsg); */
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
             uint16_t nextHop;
             //time to send ping reply
             dbg(GENERAL_CHANNEL, "PING REPLY EVENT \n");
             dbg(GENERAL_CHANNEL, "-----------------\n");

             /* sequence++; //increment the sequence number */

             makePack(&temp, myMsg->dest, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequence, (uint8_t*)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
             dbg(GENERAL_CHANNEL, "Sending Ping Reply Packet below\n");
             logPack(&temp);

             nextHop = call DistanceVector.getNextHop(temp);
             dbg(ROUTING_CHANNEL, "pack recieved, implementing dvr\n");
             if(nextHop == 256) {
               dbg(ROUTING_CHANNEL, "infinite cost or node not in table \n");
               call FloodingHandler.flood(temp);
             } else {
               dbg(ROUTING_CHANNEL, "Sending to Node: %d\n", nextHop);
               call Sender.send(temp, nextHop);
             }

           } else if (myMsg->protocol == 1) {
             uint8_t i;
             uint16_t size;
             dbg(GENERAL_CHANNEL, "Ping Reply received for packet and resetting timer\n");
             logPack(myMsg);
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
      uint16_t nextHop;
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
      logPack(&sendPackage);

      isRunning = call sendPacketAgain.isRunning();
      //only start timer if the timer is stopped aka no packets are being currently being sent again
      if(!isRunning) {
        call sendPacketAgain.startPeriodic( INTERVAL_TIME + (uint16_t) (call Random.rand16()%200) );
      }

      //add packet into the sentPackets lists
      call sentPackets.pushback(sendPackage);
      timeNow = call sendPacketAgain.getNow();
      call sentPacketsTime.pushback(timeNow);
      call sentPacketsTimesToSendAgain.pushback(TIMES_TO_SEND_PACKET);

      nextHop = call DistanceVector.getNextHop(sendPackage);
      if(nextHop == 256) {
        dbg(ROUTING_CHANNEL, "infinite cost or node not in table \n");
        call FloodingHandler.flood(sendPackage);
      } else {
        call Sender.send(sendPackage, nextHop);
      }

      //increment the sequence number
      sequence++;
   }

   event void CommandHandler.printNeighbors(){
     call NeighborHandler.printNeighbors();
   }

   event void CommandHandler.printRouteTable(){
     call DistanceVector.printRouteTable();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint8_t port){
     bool bindCheck;
     dbg(TRANSPORT_CHANNEL, "Server Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "Listening at port: %d\n", port);

     fd = call Transport.socket();
     if(fd == MAX_NUM_OF_SOCKETS) {
       dbg(TRANSPORT_CHANNEL, "reached max num of sockets\n");
       return;
     }
     sockAddr.port = port;
     sockAddr.addr = TOS_NODE_ID;

     bindCheck = call Transport.bind(fd, &sockAddr);
     if(bindCheck == SUCCESS) {
       SERVER = TRUE;
       /* call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200)); */
       /* call printSocketInfo.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200)); */
       call Transport.listen(fd);
     } else {
       dbg(TRANSPORT_CHANNEL, "binding failed\n");
     }
   }

   event void CommandHandler.setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t transfer){
     // to convert from uint16 to two uint8 use >> operator
     socket_t sock;
     uint8_t *buffer[15]; //bufflen is 15 in transport.write(...)
     uint8_t i;
     bool bindCheck;
     dbg(TRANSPORT_CHANNEL, "Client Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "dest: %d\n", dest);
     dbg(TRANSPORT_CHANNEL, "srcPort: %d\n", srcPort);
     dbg(TRANSPORT_CHANNEL, "destPort: %d\n", destPort);
     dbg(TRANSPORT_CHANNEL, "bytes to transfer: %d\n", transfer);

     fd = call Transport.socket();
     if(fd == MAX_NUM_OF_SOCKETS) {
       dbg(TRANSPORT_CHANNEL, "reached max num of sockets\n");
       return;
     }
     sockAddr.port = srcPort;
     sockAddr.addr = TOS_NODE_ID;

     bindCheck = call Transport.bind(fd, &sockAddr);
     if(bindCheck == SUCCESS) {
       SERVER = FALSE;

       serAddrFromC.port = destPort;
       serAddrFromC.addr = dest;

       bToTransfer = transfer;

       call Transport.connect(fd, &serAddrFromC);

       call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200)); //client side
       /* call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200)); */
     } else {
       dbg(TRANSPORT_CHANNEL, "binding failed\n");
     }
    for (i = 0; i < 15; i++) {
      buffer[i] = transfer;
    }
    sock = call Transport.write(fd, (uint8_t*) buffer, 15);


   }

   event void CommandHandler.closeClient(uint8_t dest, uint8_t srcPort, uint8_t destPort) {
     dbg(TRANSPORT_CHANNEL, "Closing Client Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "dest: %d\n", dest);
     dbg(TRANSPORT_CHANNEL, "srcPort: %d\n", srcPort);
     dbg(TRANSPORT_CHANNEL, "destPort: %d\n", destPort);

     //get fd based on src port, destport, and dest later
     call Transport.close(fd);
   }

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
