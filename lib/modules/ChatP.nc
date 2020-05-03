#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module ChatP {
    provides interface Chat;
    // uses interface Packet;
    uses interface SimpleSend as Sender;
    uses interface Transport;

    uses interface Timer<TMilli> as nameTimer;
    /* uses interface Timer<TMilli> as clientTimer; */
    uses interface Timer<TMilli> as readTimer;
    /* uses interface List<socket_t> as connections; */
    uses interface Random as Random;

}

implementation {
    socket_t fd[MAX_NUM_OF_SOCKETS]; //both
    uint8_t newfdsize = 0; //both
    bool SERVER;

    uint8_t names[MAX_NUM_OF_SOCKETS][128];
    uint8_t nameSizes[MAX_NUM_OF_SOCKETS];
    socket_t connections[MAX_NUM_OF_SOCKETS];
    uint8_t connectionSize = 0;

    /* socket_t client; */
    /* bool listUsrReply = FALSE; */

    uint8_t name[100]; // client
    uint8_t nameSize;


    event void nameTimer.fired() {
      if(!SERVER) { //client
        //send name
        uint8_t namee[128];
        memcpy(namee, (uint8_t*)"H ", 2);
        memcpy(namee+2, name, nameSize);

        dbg(CHAT_CHANNEL, "namee: -%s-, and size: %d\n", namee, nameSize+2);

        call Transport.write(connections[connectionSize-1], namee, nameSize+2);
        call nameTimer.stop();
        call readTimer.startPeriodic(12500 + (uint16_t) (call Random.rand16()%200));
      } else {
        //read the name
        uint8_t buff[128];
        uint16_t bufflen;
        socket_t sockForName = connections[connectionSize-1];

        dbg(CHAT_CHANNEL, "reading name\n");

        bufflen = call Transport.read(sockForName, buff, 128);

        dbg(CHAT_CHANNEL, "recieved buff: -%s- and size: %d\n", buff, bufflen);

        if(bufflen != 0) {
          uint8_t strName[bufflen+1];
          bufflen -= 2;
          memcpy(strName, buff+2, bufflen);
          strName[bufflen] = '\0';

          memcpy(names[connectionSize-1],strName,bufflen);
          nameSizes[connectionSize-1] = bufflen;

          dbg(CHAT_CHANNEL, "recieved name: -%s-\n", names[connectionSize-1]);

          call nameTimer.stop();
          call readTimer.startPeriodic(5500 + (uint16_t) (call Random.rand16()%200));
        }
      }

    }

    event void readTimer.fired() {
      uint16_t bufflen;
      uint8_t i;
      uint8_t j;
      uint8_t k;
      for(i = 0; i < connectionSize; i++) {
        uint8_t buff[128];
        //keep reading until 0;
        /* do { */
        bufflen = call Transport.read(connections[i], buff, 128);
        /* } while(bufflen != 0); */

        if(bufflen != 0) {
          dbg(CHAT_CHANNEL, "len received: -%d-\n", bufflen);
          dbg(CHAT_CHANNEL, "recieved str: -%s-\n", (char*)buff);
          /* for(j = 0; j < bufflen; j++) {
            dbg(CHAT_CHANNEL, "uint8 conversion: %d\n", buff[j]);
          } */

          //list users
          if(buff[0] == 'l') {
            if(SERVER) {
              /* uint8_t buffer[128];
              uint8_t* header = (uint8_t*) "l-"+connectionSize;
              uint8_t* lhead = (uint8_t*) "l-";
              uint8_t size = 3; //assuming single digit connection size
              uint8_t j;

              dbg(CHAT_CHANNEL, "sending to: -%d-\n", connections[i]);

              memcpy(buffer, header, size);
              memcpy(buffer+size, (uint8_t*) "\0 ", 1);
              size += 1;
              call Transport.write(connections[i], buffer, size);

              for(j = 0; j < connectionSize; j++) {
                memcpy(buffer+size, lhead, 2);
                size += 2;

                memcpy(buffer+size, names[j], nameSizes[j]);
                size += nameSizes[j];
                memcpy(buffer+size, (uint8_t*) "\0 ", 1);
                size += 1;

                call Transport.write(connections[i], buffer, size);
                size = 0;
              } */


              uint8_t buffer[128];
              uint8_t* header = (uint8_t*) "listUsrReply ";
              uint8_t size = 13;
              uint16_t read;
              uint8_t* comma = (uint8_t*) ", ";

              memcpy(buffer, header, size);
              for(j = 0; j < connectionSize; j++) {

                memcpy(buffer+size, names[j], nameSizes[j]);
                size += nameSizes[j];

                if(connectionSize - 1 != j) {
                  memcpy(buffer+size, comma, 2);
                  size += 2;
                }
              }
              memcpy(buffer+size, (uint8_t*) "\0 ", 1);
              size += 1;

              read = call Transport.write(connections[i], buffer, size)-1;


              dbg(CHAT_CHANNEL, "final str: %s; and wrote: %d, size %d for connection: %d\n", buffer,read, size, connections[i]);

              /* for(j = 0; j < size; j++) {
                dbg(CHAT_CHANNEL, "uint8 conversion: %d\n", buffer[j]);
              } */
            } else {
              dbg(CHAT_CHANNEL, "client list\n");
              dbg(CHAT_CHANNEL, "client str: ~%s~\n", buff);

            }
          } else if(buff[0] == 'H' && SERVER) {

            uint8_t strName[bufflen+1];
            bufflen -= 2;
            memcpy(strName, buff+2, bufflen);
            strName[bufflen] = '\0';

            memcpy(names[connectionSize-1],strName,bufflen);
            nameSizes[connectionSize-1] = bufflen;

            dbg(CHAT_CHANNEL, "recieved name: -%s-\n", strName);

          } else if(buff[0] == 'w') {
            uint8_t buffer[128];
            uint8_t bufferSize = 0;
            uint8_t nameToCheck[128];
            uint8_t size = 0;
            char c;


            memcpy(buffer, buff+8, bufflen-8-1);
            bufferSize = bufflen-8-1;
            memcpy(buffer+bufferSize, (uint8_t*) "\0 ", 1);
            bufferSize += 1;

            //get the name and send it to them
            do {
              c = buffer[size];
              size += 1;
              if(size == 30){
                break;
              }
            } while(c != ' ');

            memcpy(nameToCheck, buffer, size);

            for(j = 0; j < connectionSize; j++) {
              bool equal = TRUE;
              /* dbg(CHAT_CHANNEL, "name: %s, name to check size: %d, their size: %d\n", names[j], size, nameSizes[j]); */

              for(k = 0; k < nameSizes[j] || k < size-1; k++) {
                /* dbg(CHAT_CHANNEL, "names[j][k]: %c, nameToCheck[k]: %c, equal: %d\n", names[j][k], nameToCheck[k], (uint8_t)(names[j][k] == nameToCheck[k])); */
                if(names[j][k] != nameToCheck[k]) {
                  equal = FALSE;
                  break;
                }
              }
              if(equal == TRUE) {
                /* dbg(CHAT_CHANNEL, "name: %s\n", names[j]); */
                call Transport.write(connections[j], buffer, bufferSize);
              }
            }


            dbg(CHAT_CHANNEL, "recieved rest buffer: -%s-\n", buffer);

          } else if(buff[0] == 'm') {
            if(SERVER) {
              //from connection[i] so name is names[i]
              uint8_t buffer[128];
              uint8_t bufferSize = 0;

              memcpy(buffer, buff, 4); //copy "msg "
              bufferSize += 4;

              memcpy(buffer+bufferSize, names[i], nameSizes[i]);
              bufferSize += nameSizes[i];

              memcpy(buffer+bufferSize, (uint8_t*) " ", 1);
              bufferSize += 1;

              memcpy(buffer+bufferSize, buff+4, bufflen-9);
              bufferSize += bufflen-9;

              memcpy(buffer+bufferSize, (uint8_t*) "\0 ", 1);
              bufferSize += 1;

              for(j = 0; j < connectionSize; j++) {
                call Transport.write(connections[j], buffer, bufferSize);
              }

              dbg(CHAT_CHANNEL, "final msg: -%s-, size: %d\n", buffer, bufferSize);

            } else {
              dbg(CHAT_CHANNEL, "recieved chat msg: -%s-\n", buff);

            }

          }

        }
      }
    }

    /* event void clientTimer.fired() {
        dbg(CHAT_CHANNEL, "Client Timer Started");
    } */

    //all clients
    command void Chat.handleCommand(uint8_t* cmd, uint8_t cmdSize, uint8_t* rest, uint8_t restSize, uint8_t* fullMsg) {
      uint8_t cmdNew[cmdSize];
      uint8_t restNew[restSize];
      memcpy(cmdNew, cmd, cmdSize);
      memcpy(restNew, rest, restSize);
      /* cmdNew[cmdSize] = '\0'; */

      /* dbg(CHAT_CHANNEL, "cmd: %s\n", cmdNew); */
      if(cmdNew[0] == 'H') {
        socket_addr_t sockAddr;
        bool bindCheck;
        SERVER = FALSE;

        //need to parse the port
        //assuming port is only one number
        dbg(CHAT_CHANNEL, "rest port: %d\n", restNew[restSize-1]-48);
        sockAddr.port = restNew[restSize-1]-48;

        //save name
        memcpy(name, restNew, restSize-2);
        /* dbg(CHAT_CHANNEL, "name: -%s-\n", name); */
        nameSize = restSize-2;


        fd[newfdsize] = call Transport.socket();
        if(fd[newfdsize] == MAX_NUM_OF_SOCKETS) {
          dbg(TRANSPORT_CHANNEL, "reached max num of sockets\n");
          return;
        }
        sockAddr.addr = TOS_NODE_ID;

        bindCheck = call Transport.bind(fd[newfdsize], &sockAddr);
        if(bindCheck == SUCCESS) {
          socket_addr_t dest;

          dest.port = 41;
          dest.addr = 1;

          call Transport.connect(fd[newfdsize], &dest);


          /* call stopWait.startPeriodic(INTERVAL_TIME*3 + (uint16_t) (call Random.rand16()%200)); //client side */
          /* call clientWrite.startPeriodic(INTERVAL_TIME*4 + (uint16_t) (call Random.rand16()%200)); */
        } else {
          dbg(CHAT_CHANNEL, "binding failed\n");
        }
      } else if(fullMsg[0] == 'l') {
        uint8_t listusers[7] = "listusr";
        /* uint16_t len; */
        /* dbg(CHAT_CHANNEL, "lethrtehtr"); */
        call Transport.write(connections[0], listusers, 7);
        /* dbg(CHAT_CHANNEL, "len: %d", len); */
      } else if(fullMsg[0] == 'w') {
        char ch;
        uint8_t size = 0;
        do {
          ch = fullMsg[size];
          /* dbg(CHAT_CHANNEL, "char: %c\n", ch); */
          size += 1;
          if(size == 30) {
            break;
          }
        } while(ch != '\r');
        /* fullMsg[size]= '\0'; */
        call Transport.write(connections[0], fullMsg, size);
      } else if(fullMsg[0] == 'm') {
        char ch;
        uint8_t size = 0;
        do {
          ch = fullMsg[size];
          size += 1;
          if(size == 30) {
            break;
          }
        } while(ch != '\r');

        /* memcpy(fullMsg+size, name, nameSize); */
        call Transport.write(connections[0], fullMsg, size+nameSize);
      }

    }

    command void Chat.newConnection(socket_t newfd) {
      connections[connectionSize] = newfd;
      /* dbg(CHAT_CHANNEL, "fwefew\n"); */
      //need to get name now for the server;
      if(!SERVER) {
        //send data packet with name;
        /* dbg(CHAT_CHANNEL, "sending name: %s with size %d\n", name, nameSize); */
        /* call Transport.write(newfd, name, nameSize); */
        /* dbg(CHAT_CHANNEL, "wrote name: %d\n", size); */

        call nameTimer.startPeriodic(500+(uint16_t) (call Random.rand16()%200));
      } else {
        if(!call readTimer.isRunning()) {
          call nameTimer.startPeriodic(3500+(uint16_t) (call Random.rand16()%200));
        }
        //wait some time and read the buffer for the name
      }
      connectionSize += 1;
    }

    command void Chat.startChatServer(uint8_t port) {
      socket_addr_t sockAddr;
      bool bindCheck;

      fd[newfdsize] = call Transport.socket();
      if(fd[newfdsize] == MAX_NUM_OF_SOCKETS) {
        dbg(CHAT_CHANNEL, "reached max num of sockets\n");
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
        dbg(CHAT_CHANNEL, "binding failed\n");
      }
    }

    command void Chat.startChatClient(uint8_t port, uint8_t* username) { //start chat client and try to connect to port 41 and node 1
        /* socket_t sock;
        socket_addr_t srcAddr;
        socket_addr_t destAddr;
        uint8_t buff[SOCKET_BUFFER_SIZE];
        uint8_t write;
        sock = call Transport.socket();

        srcAddr.port = port;
        srcAddr.addr = TOS_NODE_ID;

        destAddr.port = 41; // connect to port 41
        destAddr.addr= 1; // node 1

        if(call Transport.socket() != NULL) {

            dbg(CHAT_CHANNEL, "This is socket %d\n", sock);

            if (call Transport.bind(sock, &srcAddr) == SUCCESS) {

                dbg(CHAT_CHANNEL, "Socket %d has binded to address: %d, port: %d\n", sock, srcAddr.addr, srcAddr.port);
                dbg(CHAT_CHANNEL, "Attempting to connect to server with port %d at address %d\n", destAddr.port, destAddr.addr);

                if(call Transport.connect(sock, &srcAddr) == SUCCESS) {
                    dbg(CHAT_CHANNEL, "Socket %d connected succesfully\n", sock);

                    write = call Transport.write(sock, buff, strlen((char*)buff));
                    // sprintf(buff, "Hello %s%c%c%c%c%c\n", (char*)username, 92, 114, 92, 110, '\0'); // /r/n
                    dbg(CHAT_CHANNEL, "Hello %s %c%c%c%c%c", (char*)username, 92, 114, 92, 110, '\0'); // /r/n
                    // 92 = /
                    // 114 = r
                    // 110 = n
                }
            }
            return SUCCESS;
        }

        dbg(CHAT_CHANNEL, "Error! Socket %d connection failed", sock);
        return FAIL; */
    }

    command void Chat.broadcast(uint8_t* message) {
        /* uint8_t write;
        char msg[SOCKET_BUFFER_SIZE];

        write = call Transport.write(client, msg, strlen((char*)msg));
        dbg(CHAT_CHANNEL, "msg %s%c%c%c%c%c\n", (char*)message, 92, 114, 92, 110, '\0'); */
    }

    command void Chat.unicast(uint8_t* username, uint8_t* message) {
        /* uint8_t write;
        char msg[SOCKET_BUFFER_SIZE];

        write = call Transport.write(client, msg, strlen((char*)msg));
        dbg(CHAT_CHANNEL, "To client %s msg %s%c%c%c%c%c\n", (char*)username, (char*)message, 92, 114, 92, 110,'\0'); */
    }

}
