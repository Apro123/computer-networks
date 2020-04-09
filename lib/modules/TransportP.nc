#include <Timer.h>
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/tcpHeader.h"

module TransportP {
  provides interface Transport;
  uses interface Packet;
  uses interface SimpleSend as Sender;

  uses interface List<socket_t> as newEstaSock; //fd can be 0-9
  uses interface List<socket_store_t> as sockets;

  uses interface Timer<TMilli> as socketTimer;
  uses interface Random as Random;

  uses interface DistanceVector;

  uses interface FloodingHandler;

  uses interface Timer<TMilli> as closeTimer;
}
implementation {
  socket_t newList[MAX_NUM_OF_SOCKETS+1]; 
  socket_t socketIndex = 0;
  uint16_t sockSeq[MAX_NUM_OF_SOCKETS]; // 10
  uint16_t randomSeq = 0;
  pack packTempSA; 
  socket_t toClose = MAX_NUM_OF_SOCKETS;

  event void socketTimer.fired() {
    dbg(TRANSPORT_CHANNEL, "timer in transportP fired\n");
  }

  event void closeTimer.fired() {
    socket_store_t temp = call sockets.get(toClose); 
    dbg(TRANSPORT_CHANNEL, "setting socket to closed\n");
    temp.state = CLOSED;
    call sockets.set(toClose, temp); 
  }

  command bool Transport.isEstablished(socket_t t) {
    socket_store_t temp = call sockets.get(t);
    if(temp.state == ESTABLISHED) {
      return TRUE;
    }
    return FALSE;
  }

  command socket_t* Transport.getNewlyEstablished() {
    //return all newly established
    //first "socket_t" stores size of the list;
    uint16_t listSize = call newEstaSock.size();
    if(listSize > 0) {
      uint8_t i;
      newList[0] = listSize;

      for(i = 0; i < listSize; i++) {
        newList[i+1] = call newEstaSock.get(i);
      }

      return newList;
    } else {
      return NULL;
    }
  }

  command error_t Transport.fireSynAckAgain() {
    uint16_t nextHop;
    dbg(TRANSPORT_CHANNEL, "Firing syn ack again\n");

    nextHop = call DistanceVector.getNextHop(packTempSA);
    if(nextHop == 256) {
      dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
      call FloodingHandler.flood(packTempSA);
    } else {
      call Sender.send(packTempSA, nextHop);
    }
  }

  //server only
  error_t fireSynAck(socket_t fd, pack* package)  { 
    socket_store_t sock = call sockets.get(fd); //got from call
    if(sock.state == SYN_RCVD) {
      //send synack packet
      uint16_t nextHop;
      tcpHeader tcpTempSA;
      tcpHeader* prev;
      /* packTempSA = package; */

      packTempSA.dest = package->src;
      packTempSA.src = TOS_NODE_ID; //or package->dest
      packTempSA.seq = randomSeq; //random
      packTempSA.TTL = 0; //no data to store
      packTempSA.protocol = 4;
      prev = (tcpHeader*) package->payload;

      tcpTempSA.srcPort = prev->destPort; //flip the src and dest port
      tcpTempSA.destPort = prev->srcPort; 

      if(!sockSeq[fd]) {
        sockSeq[fd] = 1;
      }

      tcpTempSA.seq = sockSeq[fd];
      tcpTempSA.ack = prev->seq + 1;
      tcpTempSA.flag = SYN_ACK;
      tcpTempSA.advertisedWindow = 0;
      memcpy(&(tcpTempSA.data), &(prev->data), sizeof(TCP_PACKET_MAX_PAYLOAD_SIZE)); //random data
      /* tcpTempSA.data = prev.data; //random data */

      memcpy(packTempSA.payload, &tcpTempSA, sizeof(TCP_PACKET_HEADER_LENGTH));

      dbg(TRANSPORT_CHANNEL, "sending SYN_ACK tcp flag = %d\n", tcpTempSA.flag);

      nextHop = call DistanceVector.getNextHop(packTempSA);
      if(nextHop == 256) {
        dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
        call FloodingHandler.flood(packTempSA);
      } else {
        call Sender.send(packTempSA, nextHop);
      }

      sockSeq[fd] = sockSeq[fd] + 1;
      randomSeq = randomSeq + 1;

      return SUCCESS;
    } else {
      dbg(TRANSPORT_CHANNEL, "socket state not SYN! Abort!\n");
      return FAIL;
    }
  }

  /**
   * Get a socket if there is one available.
   * @Side Client/Server
   * @return
   *    socket_t - return a socket file descriptor which is a number
   *    associated with a socket. If you are unable to allocated
   *    a socket then return a NULL socket_t.
   */
  command socket_t Transport.socket() {
    socket_t temp = socketIndex;
    if(temp >= MAX_NUM_OF_SOCKETS) {
      /* socket_t nul; */
      return MAX_NUM_OF_SOCKETS;
    } else {
      socket_store_t sock = call sockets.get(temp);
      if(sock.state != CLOSED) {
        dbg(TRANSPORT_CHANNEL, "socket state not CLOSED! Abort!\n");
        return MAX_NUM_OF_SOCKETS;
      }
      socketIndex += 1;
      return temp;
    }
  }

  /**
   * Bind a socket with an address.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       you are binding.
   * @param
   *    socket_addr_t *addr: the source port and source address that
   *       you are binding to the socket, fd.
   * @Side Client/Server
   * @return error_t - SUCCESS if you were able to bind this socket, FAIL
   *       if you were unable to bind.
   */
  command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {
    //allocate new socket_store_t for socket_t fd
    socket_store_t temp;
    uint16_t size;
    size = call sockets.size();
    if(size == MAX_NUM_OF_SOCKETS) {
      dbg(TRANSPORT_CHANNEL, "max num of sockets reached\n");
      return FAIL;
    }
    temp.state = CLOSED;
    temp.src = addr->port;
    /* temp.dest.addr = addr->addr; */
    call sockets.pushback(temp);
    return SUCCESS;
  }

  /**
   * Checks to see if there are socket connections to connect to and
   * if there is one, connect to it.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that is attempting an accept. remember, only do on listen.
   * @side Server
   * @return socket_t - returns a new socket if the connection is
   *    accepted. this socket is a copy of the server socket but with
   *    a destination associated with the destination address and port.
   *    if not return a null socket.
   */
  command socket_t Transport.accept(socket_t fd) {
    //if accepted then pushback to newEstaSock
    socket_store_t temp = call sockets.get(fd);
    if(temp.state == SYN_RCVD || temp.state == SYN_SENT) { //server || client
      temp.state = ESTABLISHED;
      dbg(TRANSPORT_CHANNEL, "socket state changed to ESTABLISHED\n");
      call sockets.set(fd, temp);
      call newEstaSock.pushback(fd);
      return fd;
    } else {
      //else return MAX_NUM_OF_SOCKETS
      dbg(TRANSPORT_CHANNEL, "state was not at SYN_RCVD\n");
      return MAX_NUM_OF_SOCKETS;
    }

  }

  /**
   * Write to the socket from a buffer. This data will eventually be
   * transmitted through your TCP implimentation.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that is attempting a write.
   * @param
   *    uint8_t *buff: the buffer data that you are going to wrte from.
   * @param
   *    uint16_t bufflen: The amount of data that you are trying to
   *       submit.
   * @Side For your project, only client side. This could be both though.
   * @return uint16_t - return the amount of data you are able to write
   *    from the pass buffer. This may be shorter then bufflen
   */
  command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {

  }

  /**
   * This will pass the packet so you can handle it internally.
   * @param
   *    pack *package: the TCP packet that you are handling.
   * @Side Client/Server
   * @return uint8_t - return 0 for fail with errors, return 1 for regular
   success, return 2 for new connection (when received ACK), return 3 for syn flag recieved (server only)

   */
  command uint8_t Transport.receive(pack* package) {
    socket_t fd;
    socket_store_t sock;
    bool found;
    uint8_t i;
    tcpHeader* t = (tcpHeader*) package->payload;

    if(package->dest != TOS_NODE_ID) {
      uint16_t nextHop;

      /* dbg(TRANSPORT_CHANNEL, "dest not this node\n"); */

      nextHop = call DistanceVector.getNextHop(*package);
      if(nextHop == 256) {
        dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
        call FloodingHandler.flood(*package);
      } else {
        call Sender.send(*package, nextHop);
      }
      return 1;
    }

    //find local socket_store_t based on dest port
    found = FALSE;
    for(i = 0; i <= socketIndex; i++) {
      sock = call sockets.get(i);
      if(sock.src == t->destPort) {
        found = TRUE;
        fd = i;
        break;
      }
    }

    if(found == FALSE) {
      dbg(TRANSPORT_CHANNEL, "could not find socket\n");
      return 0;
    }

    dbg(TRANSPORT_CHANNEL, "tcp header flag %d\n", t->flag);


    if(t->flag == ACK) {
      //server
      socket_t acceptCheck;
      acceptCheck = call Transport.accept(fd);
      if(acceptCheck != MAX_NUM_OF_SOCKETS) { //illegal
        return 2;
      } else {
        dbg(TRANSPORT_CHANNEL, "not accepted\n");
        return 0;
      }
    } else if(t->flag == SYN) {
      //server
      if(sock.state == LISTEN) {
        sock.state = SYN_RCVD;
        dbg(TRANSPORT_CHANNEL, "socket state changed to SYN_RCVD\n");
        sock.dest.addr = package->src;
        sock.dest.port = t->srcPort;
        call sockets.set(fd, sock);
        //send ack packet
        fireSynAck(fd, package);
        return 3;
      } else {
        dbg(TRANSPORT_CHANNEL, "state was not at Listen\n");
        return 0;
      }
    } else if(t-> flag == SYN_ACK) {
      //client
      if(sock.state == SYN_SENT) {
        sock.state = ESTABLISHED;
        dbg(TRANSPORT_CHANNEL, "socket state changed to ESTABLISHED\n");
        call sockets.set(fd, sock);
        return 2; //check if server or client is done in node file;
      } else {
        dbg(TRANSPORT_CHANNEL, "state was not at SYN_SENT\n");
        return 0;
      }
    } else if(t->flag == FIN) {
      toClose = fd;
      call Transport.close(fd);
    } else if(t->flag == FIN_ACK) {
      //send FIN_ACK2
      pack packTemp;
      tcpHeader tcpTemp;
      uint16_t nextHop;

      dbg(TRANSPORT_CHANNEL, "sending fin_ack 2 packet\n");

      packTemp.dest = sock.dest.addr;
      packTemp.src = TOS_NODE_ID;
      packTemp.seq = randomSeq; //random
      packTemp.TTL = 0; //no data to store
      packTemp.protocol = 4;

      tcpTemp.srcPort = sock.src; //port of the closer
      tcpTemp.destPort = sock.dest.port; //port of the closee

      if(!sockSeq[fd]) {
        sockSeq[fd] = 1;
      }

      tcpTemp.seq = sockSeq[fd];
      tcpTemp.ack = 0;
      tcpTemp.flag = FIN_ACK2;
      tcpTemp.advertisedWindow = 0;
      /* memcpy(tcpTemp.data, addr, TCP_PACKET_MAX_PAYLOAD_SIZE); //addr is a placeholder for now */

      memcpy(packTemp.payload, &tcpTemp, PACKET_MAX_PAYLOAD_SIZE);

      nextHop = call DistanceVector.getNextHop(packTemp);
      if(nextHop == 256) {
        dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
        call FloodingHandler.flood(packTemp);
      } else {
        call Sender.send(packTemp, nextHop);
      }

      sockSeq[fd] = sockSeq[fd] + 1;
      randomSeq = randomSeq + 1;

      call closeTimer.startOneShot(1500 + (uint16_t) (call Random.rand16()%200));
    } else if(t->flag == FIN_ACK2) {
      toClose = fd;
      call closeTimer.startOneShot(1500 + (uint16_t) (call Random.rand16()%200));
    }


    return 1;
  }

  /**
   * Read from the socket and write this data to the buffer. This data
   * is obtained from your TCP implimentation.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that is attempting a read.
   * @param
   *    uint8_t *buff: the buffer that is being written.
   * @param
   *    uint16_t bufflen: the amount of data that can be written to the
   *       buffer.
   * @Side For your project, only server side. This could be both though.
   * @return uint16_t - return the amount of data you are able to read
   *    from the pass buffer. This may be shorter then bufflen
   */
  command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

  }

  /**
   * Attempts a connection to an address.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that you are attempting a connection with.
   * @param
   *    socket_addr_t *addr: the destination address and port where
   *       you will atempt a connection.
   * @side Client
   * @return socket_t - returns SUCCESS if you are able to attempt
   *    a connection with the fd passed, else return FAIL.
   */
  command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
    socket_store_t sock = call sockets.get(fd);
    uint8_t destPort = addr->port;
    uint16_t destNode = addr->addr;
    pack packTemp;
    tcpHeader tcpTemp;
    uint16_t nextHop;

    if(sock.state != CLOSED) {
      dbg(TRANSPORT_CHANNEL, "socket state is not CLOSED\n");
      return FAIL;
    }

    packTemp.dest = destNode;
    packTemp.src = TOS_NODE_ID;
    packTemp.seq = randomSeq; //random
    packTemp.TTL = 0; //no data to store
    packTemp.protocol = 4;

    tcpTemp.srcPort = sock.src; //port of the client
    //reintialize the dest port and addr
    sock.dest.port = destPort; //port of the server
    sock.dest.addr = destNode;
    sock.src = tcpTemp.srcPort; //reintialize the source port
    dbg(TRANSPORT_CHANNEL, "socket state changed to SYN_SENT\n");
    sock.state = SYN_SENT;
    call sockets.set(fd, sock);

    if(!sockSeq[fd]) {
      sockSeq[fd] = 1;
    }

    tcpTemp.destPort = destPort;
    tcpTemp.seq = sockSeq[fd];
    tcpTemp.ack = 0;
    tcpTemp.flag = SYN;
    tcpTemp.advertisedWindow = 0;
    memcpy(tcpTemp.data, addr, TCP_PACKET_MAX_PAYLOAD_SIZE); //addr is a placeholder for now

    memcpy(packTemp.payload, &tcpTemp, PACKET_MAX_PAYLOAD_SIZE);

    nextHop = call DistanceVector.getNextHop(packTemp);
    if(nextHop == 256) {
      dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
      call FloodingHandler.flood(packTemp);
    } else {
      call Sender.send(packTemp, nextHop);
    }

    sockSeq[fd] = sockSeq[fd] + 1;
    randomSeq = randomSeq + 1;

    return SUCCESS;
  } ////////////////////////////////////////////////////finished connect. finish up client to server connection. (finished sending syn packet) deal with that in the server

  /**
   * Closes the socket.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that you are closing.
   * @side Client/Server
   * @return socket_t - returns SUCCESS if you are able to attempt
   *    a closure with the fd passed, else return FAIL.
   */
  command error_t Transport.close(socket_t fd) {
    socket_store_t sock = call sockets.get(fd);
    pack packTemp;
    tcpHeader tcpTemp;
    uint16_t nextHop;

    dbg(TRANSPORT_CHANNEL, "sending close packet to node: %d\n", sock.dest.addr);

    packTemp.dest = sock.dest.addr;
    packTemp.src = TOS_NODE_ID;
    packTemp.seq = randomSeq; //random
    packTemp.TTL = 0; //no data to store
    packTemp.protocol = 4;

    tcpTemp.srcPort = sock.src; //port of the closer
    tcpTemp.destPort = sock.dest.port; //port of the closee

    if(!sockSeq[fd]) {
      sockSeq[fd] = 1;
    }

    tcpTemp.seq = sockSeq[fd];
    tcpTemp.ack = 0;
    if(toClose == MAX_NUM_OF_SOCKETS) {
      tcpTemp.flag = FIN;
    } else { //else toClose == fd;
      tcpTemp.flag = FIN_ACK;
    }
    tcpTemp.advertisedWindow = 0;
    /* memcpy(tcpTemp.data, addr, TCP_PACKET_MAX_PAYLOAD_SIZE); //addr is a placeholder for now */

    memcpy(packTemp.payload, &tcpTemp, PACKET_MAX_PAYLOAD_SIZE);

    nextHop = call DistanceVector.getNextHop(packTemp);
    if(nextHop == 256) {
      dbg(TRANSPORT_CHANNEL, "infinite cost or node not in table \n");
      call FloodingHandler.flood(packTemp);
    } else {
      call Sender.send(packTemp, nextHop);
    }

    sockSeq[fd] = sockSeq[fd] + 1;
    randomSeq = randomSeq + 1;

    return SUCCESS;
  }

  /**
   * A hard close, which is not graceful. This portion is optional.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that you are hard closing.
   * @side Client/Server
   * @return socket_t - returns SUCCESS if you are able to attempt
   *    a closure with the fd passed, else return FAIL.
   */
  command error_t Transport.release(socket_t fd) {
    //fix this method
    socket_store_t temp = call sockets.get(fd);
    temp.state = CLOSED;
    call sockets.set(fd, temp);
  }

  /**
   * Listen to the socket and wait for a connection.
   * @param
   *    socket_t fd: file descriptor that is associated with the socket
   *       that you are listening for a connection.
   * @side Server
   * @return error_t - returns SUCCESS if you are able change the state
   *   to listen else FAIL.
   */
  command error_t Transport.listen(socket_t fd) {
    uint16_t size;
    size = call sockets.size();
    if(fd < size) {
      //it exists
      socket_store_t temp = call sockets.get(fd);
      if(temp.state != CLOSED) {
        dbg(TRANSPORT_CHANNEL, "socket state was not null/closed before\n");
        return FAIL;
      }
      temp.state = LISTEN;
      call sockets.set(fd, temp);
      dbg(TRANSPORT_CHANNEL, "socket state changed to LISTEN\n");
      return SUCCESS;
    } else {
      //it should have been allocated in bind
      dbg(TRANSPORT_CHANNEL, "socket should have been allocated in bind\n");

      return FAIL;
    }
  }

}
