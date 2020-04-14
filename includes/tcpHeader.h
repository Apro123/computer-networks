//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef __TCP_HEADER_H__
#define __TCP_HEADER_H__

#include "packet.h"

enum{
	TCP_PACKET_HEADER_LENGTH = 8,
	TCP_PACKET_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_PACKET_HEADER_LENGTH //= 12 items of size uint8_t able to be stored; should be at least 6 data items of size uint16_t
};

enum tcpFlag {
  ACK=0,
  PSH=1,
  RST=2,
  SYN=3,
  FIN=4,
  NS=5,
  CWR=6,
  ECE=7,
  URG=8,
  DATA=9, //data
  SYN_ACK=10, //ack of the syn
  FIN_ACK=11,
  FIN_ACK2=12,
	DATA_ACK=13
};

typedef nx_struct tcpHeader{
	nx_uint8_t srcPort;
	nx_uint8_t destPort;
  nx_uint16_t seq;
  nx_uint16_t ack;
  nx_uint8_t flag;
  nx_uint8_t advertisedWindow;
	nx_uint8_t data[TCP_PACKET_MAX_PAYLOAD_SIZE]; //size of actual data is stored in the TTL field of the packet header. size is number of uint8 words
}tcpHeader;

enum{
  AM_TCP=13
};

#endif
