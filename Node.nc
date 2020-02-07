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

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface FloodingHandler;

   uses interface Timer<TMilli> as sendPacketAgain;
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0; //sequence automatically resets to 0
   uint8_t timesToSendPacket = 3;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void sendPacketAgain.fired() {
     timesToSendPacket--;
     //dont keep sending the same packet over and over again
     if(timesToSendPacket == 0) {
       dbg(FLOODING_CHANNEL, "Reached max times packet has been sent! Stopping Timer now!\n");
       call sendPacketAgain.stop();
       return;
     } else {
       dbg(FLOODING_CHANNEL, "sendPacketAgain fired\n");

       //firing again because packet must have been lost
       call FloodingHandler.flood(sendPackage);
     }

   }

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;

         /* dbg(FLOODING_CHANNEL, "Received Packet below\n"); */
         myMsg->TTL--; //decrement TTL
         logPack(myMsg);


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

             makePack(&temp, myMsg->dest, myMsg->src, MAX_TTL, 1, sequence, (uint8_t*)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
             dbg(GENERAL_CHANNEL, "Sending Ping Reply Packet below\n");
             logPack(&temp);
             call FloodingHandler.flood(temp);

           } else if (myMsg->protocol == 1) {
             dbg(GENERAL_CHANNEL, "Ping Reply received for packet and stopping timer\n");
             dbg(GENERAL_CHANNEL, "-----------------\n");
             call sendPacketAgain.stop();
           }
         }


         /* dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload); */
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, 0, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
      logPack(&sendPackage);
      call sendPacketAgain.startPeriodic( 1500 ); //1500
      call FloodingHandler.flood(sendPackage);
      //Sender.send returns success if it sent. USELESS beacuse does not return anything if node there is not runtime in between sending

      //increment the sequence number
      sequence++;
   }

   event void CommandHandler.printNeighbors(){}

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
