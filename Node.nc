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

// Neighbor discovery
   uses interface List<uint16_t> as neighborList; // list for neighbors
   uses interface Timer<TMilli> as neighborTimer; // timer for neighbor

}

implementation{
   pack sendPackage;
   uint16_t sequence = 0; //sequence automatically resets to 0


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   task void Task() {
      pack temp;
      makePack(&temp, TOS_NODE_ID, TOS_NODE_ID, 1, 0, 0, "", PACKET_MAX_PAYLOAD_SIZE); //making a pack with TTL of 1
      call neighborTimer.startPeriodic(2500);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR); //Sending a packet to all nodes
      dbg(NEIGHBOR_CHANNEL, "Node %d sending ping\n", TOS_NODE_ID);
      // dbg(NEIGHBOR_CHANNEL, "This current node is %d\n", TOS_NODE_ID);
   }

   bool neighborListContent(uint16_t NODE_ID) { //checking for content in the list of neighbors
       uint16_t i; // new variables has to always be declared at top
      if (call neighborList.isEmpty()) {
         return 0;
      }

      for (i = 0; i < call neighborList.size(); i++) {
         if (call neighborList.get(i) == NODE_ID) {
         dbg(NEIGHBOR_CHANNEL, "NODE %d neighbor list repeated content is NODE %d\n", TOS_NODE_ID, NODE_ID);
         return 1;
         }
      }
      return 0;
   }

   void addNeighbor(uint16_t NODE_ID) { // adding the neighbors to each of the nodes
      dbg(NEIGHBOR_CHANNEL, "NODE %d's neighbors are: NODE %d\n", TOS_NODE_ID, NODE_ID);
      call neighborList.pushback(NODE_ID);
   }

  
   void nodePosition(uint16_t NODE_ID) { // extracting the position of the node
      uint16_t i;
      if (call neighborList.isEmpty() == 1) {
         for(i = 0; i < call neighborList.size(); i++) {
            if (NODE_ID == call neighborList.get(i)) {
               dbg(NEIGHBOR_CHANNEL, "Position of Node %d is %d\n", NODE_ID, i);
            }
         }
      }
      dbg(NEIGHBOR_CHANNEL, "DID NOT FIND POSITION OF NODE\n");
   }

   event void neighborTimer.fired() {
      // dbg(NEIGHBOR_CHANNEL, "Node %d sending ping\n");
      post Task(); //calling task from previous method
      
   }

   event void sendPacketAgain.fired() {
     dbg(FLOODING_CHANNEL, "sendPacketAgain fired\n");
     //firing again because packet must have been lost
     call FloodingHandler.flood(sendPackage); //GETTING DROPPED because of packet already exists within the hash map. possible solution is to increase sequence number. other possible solution is to use a timer in flooding handler to delete previous packets after a certain time.
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
      // uint16_t i;
      // uint16_t j;
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      // dbg(NEIGHBOR_CHANNEL, "NODE %d RECEIVED PACKET\n", TOS_NODE_ID); //seeing which node is recieving packet
      
      // call neighborList.pushback(TOS_NODE_ID);
      if(call neighborList.isEmpty()) {
         dbg(NEIGHBOR_CHANNEL, "NODE %d is being pushed back in list\n", TOS_NODE_ID);
         call neighborList.pushback(TOS_NODE_ID);
      }

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         uint8_t tempTTL;

         /* dbg(FLOODING_CHANNEL, "Received Packet below\n"); */
         tempTTL = myMsg->TTL;
         myMsg->TTL = tempTTL - 1; //decrement TTL
         logPack(myMsg);
         // dbg(NEIGHBOR_CHANNEL, "this is TTL %d\n", myMsg->TTL);

         if(myMsg->TTL != 0 && myMsg->src == myMsg->dest) {
            dbg(NEIGHBOR_CHANNEL, "NEIGHBOR DISCOVERED\n");
            dbg(NEIGHBOR_CHANNEL, "src: %d  dest: %d\n", myMsg->src, myMsg->dest);
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
             sequence++;
             /* memcpy(tempPayload, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE); */
             /* dbg(GENERAL_CHANNEL, "gerrgwewgr \n"); */
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
      call sendPacketAgain.startPeriodic( 1500 );
      call FloodingHandler.flood(sendPackage);
      /* call Sender.send(sendPackage, destination); // AM_BROADCAST_ADDR */
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
      // call neighborList.printNeighbors();

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
