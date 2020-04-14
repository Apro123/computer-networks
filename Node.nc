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

   uses interface List<socket_t> as acceptedSockets; //both
   uses interface Timer<TMilli> as stopWait; //both

   uses interface Timer<TMilli> as printSocketInfo; //read data from socket server
   uses interface Timer<TMilli> as clientWrite; //wrtie data into socket client
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0; //sequence automatically resets to 0
   uint8_t TIMES_TO_SEND_PACKET = 3;
   uint32_t INTERVAL_TIME = 2500; // This is an arbitiary number. It is also the same number as the timers in FloodingHandlerP so if you all of the timers should start periodically a the same interval
   socket_t fd[MAX_NUM_OF_SOCKETS]; //used by both to establish connection
   uint8_t newfdsize = 0; //both
   /* uint8_t bToTransfer; //0 to transfer */
   /* uint8_t lastByteWritten; */
   bool SERVER;
   uint16_t transfer[MAX_NUM_OF_SOCKETS]; //client
   uint16_t transfered[MAX_NUM_OF_SOCKETS]; //client
   socket_addr_t serAddrFromC[MAX_NUM_OF_SOCKETS];//client
   uint8_t numSockets = 0; //client

   /* uint8_t* buffData; //client */

   /* uint16_t lastBitWritten;
   uint8_t buffData; */

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void printSocketInfo.fired() {
     uint8_t i;
     uint8_t done = 0;
     /* dbg(TRANSPORT_CHANNEL, "socket read info fired. size: %d\n", call acceptedSockets.size()); */

     for(i = 0; i < call acceptedSockets.size(); i++) {
       socket_t fd_temp;
       uint8_t buffSize;
       uint8_t buff[SOCKET_BUFFER_SIZE];
       uint16_t realdata[6]; //6 uint16_t words
       uint8_t j = 0;

       fd_temp = call acceptedSockets.get(i);
       buffSize = call Transport.read(fd_temp, buff, SOCKET_BUFFER_SIZE);

       /* dbg(TRANSPORT_CHANNEL, "buff size: %d\n", buffSize); */


       if(buffSize > 0) {
         uint8_t leftover = 0;
         for(j=0; j<buffSize/2; j++) {
           realdata[leftover] = ((uint16_t) buff[j*2]<<8) + (uint16_t) buff[j*2+1];
           leftover += 1;
           if(leftover%6 == 0) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu,%hu,%hu,%hu,%hu,%hu\n", realdata[0], realdata[1], realdata[2], realdata[3], realdata[4], realdata[5]);
             leftover = 0;
           }
         }
         if(leftover > 0) {
           if(leftover == 1) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu\n", realdata[0]);
           } else if (leftover == 2) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu,%hu\n", realdata[0], realdata[1]);

           } else if (leftover == 3) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu,%hu,%hu\n", realdata[0], realdata[1], realdata[2]);

           } else if (leftover == 4) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu,%hu,%hu,%hu\n", realdata[0], realdata[1], realdata[2], realdata[3]);

           } else if (leftover == 5) {
             dbg(TRANSPORT_CHANNEL, "Reading data: %hu,%hu,%hu,%hu,%hu\n", realdata[0], realdata[1], realdata[2], realdata[3], realdata[4]);

           } else {
             dbg(TRANSPORT_CHANNEL, "wtf leftover: %hhu\n", leftover);
           }

         }

       } else {
         done += 1;
       }

     }
     if(done == call acceptedSockets.size()) {
       call printSocketInfo.stop();
     }
   }

   event void clientWrite.fired() {
     //if buffer is not empty and transfer is not done
     // subtract transfer to keep track of data
       //there is data to be written
    uint8_t i;
    uint8_t done = 0;

    for(i = 0; i < numSockets; i++) {
      /* dbg(TRANSPORT_CHANNEL, "client write fired. numSockets: %d, transfered[i]+1: %d, transfer[i]: %d\n", numSockets, transfered[i]+1, transfer[i]); */

      if(transfered[i]+1 != transfer[i]) {
        // there is data to be written
        socket_t tempfd = call acceptedSockets.get(i);
        uint16_t dataWritten;
        uint8_t tempBuff[transfer[i]*2];
        uint16_t j;
        uint16_t counter=0;

        for(j = transfered[i]+1; j <= transfer[i]; j++) {
          uint16_t tempNum = j;
          tempBuff[counter*2] = (uint8_t)(j >> 8);
          tempBuff[(counter*2)+1] = (uint8_t)(tempNum);
          /* dbg(TRANSPORT_CHANNEL, "data: %hhu, data: %hhu\n", tempBuff[counter*2], tempBuff[(counter*2)+1]); */
          counter += 1;
        }

        dataWritten = call Transport.write(tempfd, tempBuff, counter*2);

        /* dbg(TRANSPORT_CHANNEL, "data written: %d\n", dataWritten); */

        transfered[i] += (dataWritten/2)-1;
      } else {
        /* dbg(TRANSPORT_CHANNEL, "done Writing data\n"); */
        done += 1;
      }
    }

    if(done == numSockets) {
      /* dbg(TRANSPORT_CHANNEL, "done Writing data\n"); */
      call clientWrite.stop();
    }

    /* dbg(TRANSPORT_CHANNEL, "client done\n"); */

   }

   event void stopWait.fired() {
     bool cont; //continue if connection is established
     uint8_t i;
     uint8_t temp = newfdsize;
     for(i = 0; i < temp; i++) {
       cont = call Transport.isEstablished(fd[i]);
       if(cont) {
         newfdsize -= 1;
         if(SERVER) {
             /* dbg(TRANSPORT_CHANNEL, "reading data now\n"); */
             call printSocketInfo.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
           } else {
             call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
           }
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
           uint8_t newEstaCheck;
           //TTL used to store number of data "items" (uint16_t size words)
           newEstaCheck = call Transport.receive(myMsg);
           //check if new socket connection, then stop the timer and signal printSocketInfo timer.fired() event to accept the connection
           if(newEstaCheck == 2 || newEstaCheck == 3) {
             socket_t* newfd;
             if(newEstaCheck == 2) {
               //client
               dbg(TRANSPORT_CHANNEL, "CLIENT CONNECTION ESTABLISHED\n");
               call stopWait.stop();
               call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200));
             } else {
               //server
               dbg(TRANSPORT_CHANNEL, "SERVER CONNECTION ESTABLISHED\n");
               call stopWait.stop();
               call printSocketInfo.stop();
               call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200));
             }
             //add into accepted sockets
             newfd = call Transport.getNewlyEstablished();
             /* dbg(TRANSPORT_CHANNEL, "newfd\n"); */
             if(newfd != NULL) {
               uint8_t j;
               uint8_t size;
               size = (uint8_t) newfd[0];
               /* dbg(TRANSPORT_CHANNEL, "newfd not null\n"); */
               for(j=0; j < size; j++) {
                 /* dbg(TRANSPORT_CHANNEL, "adding socket_t : %d\n", newfd[j+1]); */
                 call acceptedSockets.pushback(newfd[j+1]);
               }
               /* call acceptedSockets.pushback(newfd); */
             }

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
     socket_addr_t sockAddr;
     bool bindCheck;
     dbg(TRANSPORT_CHANNEL, "Server Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "Listening at port: %d\n", port);

     fd[newfdsize] = call Transport.socket();
     if(fd[newfdsize] == MAX_NUM_OF_SOCKETS) {
       dbg(TRANSPORT_CHANNEL, "reached max num of sockets\n");
       return;
     }

     sockAddr.port = port;
     sockAddr.addr = TOS_NODE_ID;

     bindCheck = call Transport.bind(fd[newfdsize], &sockAddr);
     if(bindCheck == SUCCESS) {
       SERVER = TRUE;
       /* call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200)); */
       /* call printSocketInfo.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200)); */
       call Transport.listen(fd[newfdsize]);
       newfdsize += 1;

     } else {
       dbg(TRANSPORT_CHANNEL, "binding failed\n");
     }
   }

   event void CommandHandler.setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t transferTop, uint8_t transferBottom){
     // to convert from uint16 to two uint8 use >> operator
     //  socket_store_t sock;
     socket_addr_t sockAddr;
     uint16_t tempTransfer;
     /* uint8_t i; */
     bool bindCheck;
     tempTransfer = ((uint16_t) transferTop<<8) | transferBottom;
     dbg(TRANSPORT_CHANNEL, "Client Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "dest: %d\n", dest);
     dbg(TRANSPORT_CHANNEL, "srcPort: %d\n", srcPort);
     dbg(TRANSPORT_CHANNEL, "destPort: %d\n", destPort);
     dbg(TRANSPORT_CHANNEL, "bytes to transfer: %hu\n", tempTransfer);

     fd[newfdsize] = call Transport.socket();
     if(fd[newfdsize] == MAX_NUM_OF_SOCKETS) {
       dbg(TRANSPORT_CHANNEL, "reached max num of sockets\n");
       return;
     }
     sockAddr.port = srcPort;
     sockAddr.addr = TOS_NODE_ID;

     bindCheck = call Transport.bind(fd[newfdsize], &sockAddr);
     if(bindCheck == SUCCESS) {
       /* uint8_t tempBuff[transfer]; */
       SERVER = FALSE;

       serAddrFromC[numSockets].port = destPort;
       serAddrFromC[numSockets].addr = dest;

       call Transport.connect(fd[newfdsize], &serAddrFromC[numSockets]);

       transfer[numSockets] = tempTransfer;
       transfered[numSockets] = 0;

       newfdsize += 1;
       numSockets += 1;

       call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200)); //client side
       /* call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200)); */
     } else {
       dbg(TRANSPORT_CHANNEL, "binding failed\n");
     }



     //buff data is initialized

     //client write is called later

    /* call clientWrite.startPeriodic(INTERVAL_TIME*8 + (uint16_t) (call Random.rand16()%200)); */

    // lastBitWritten = call Transport.write(fd, (uint8_t*) transfer, (uint16_t) 15);
    // dbg(TRANSPORT_CHANNEL, "the last bit written is %d\n", lastBitWritten);


    // for (i = 0; i < transfer; i++) {
    //   buffer[i] = call Transport.write(fd, (uint8_t *) transfer, 15);
    //   dbg(TRANSPORT_CHANNEL, "buffer includes %d\n", buffer[i]);
    // }
    /* lastBitWritten = call Transport.write(fd, (uint8_t*) transfer, sizeof(buffer)); */

    // First initialize the buffer which will be a global variable
    // from there we would call the clientWrite timer
    // after calling the timer we would then call transport.write
    // from there transport.write will give us number of how much is left
    // Then we would take that number and put it in a new buffer and truncate it
    // from whatever is left in the new buffer we would then put that back in the old buffer


    // transfer number 17 //global var
    // uint8_t * buff[transfer] // in this method
    // Then push into the buff

    // in the write timer
    // lastbitwritteninto the socket = 13 // global variable and 13 because uint8_t
    // 14, 15, 16, ... 17 

   }

   event void CommandHandler.closeClient(uint8_t dest, uint8_t srcPort, uint8_t destPort) {
     uint8_t i;
     socket_t tfd = MAX_NUM_OF_SOCKETS;
     dbg(TRANSPORT_CHANNEL, "Closing Client Node %d\n", TOS_NODE_ID);
     dbg(TRANSPORT_CHANNEL, "dest: %d\n", dest);
     dbg(TRANSPORT_CHANNEL, "srcPort: %d\n", srcPort);
     dbg(TRANSPORT_CHANNEL, "destPort: %d\n", destPort);

     //get fd based on src port, destport, and dest later
     for(i = 0; i < numSockets; i++) {
       if(serAddrFromC[i].port == destPort && serAddrFromC[i].addr == dest) {
         tfd = fd[i];
         break;
       }
     }
     if(tfd == MAX_NUM_OF_SOCKETS) {
       dbg(TRANSPORT_CHANNEL, "Unable to close\n");
       return;
     }
     call Transport.close(tfd);
     /* call Transport.close(fd); */
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
