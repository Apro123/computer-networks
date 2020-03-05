//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


#include "protocol.h"
#include "channels.h"

enum{
	PACKET_HEADER_LENGTH = 8,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	MAX_TTL = 15
};


typedef nx_struct pack{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;		//Sequence Number
	nx_uint8_t TTL;		//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;

typedef nx_struct dvrPayload{
	nx_uint16_t payload_Dest[255];
	nx_uint16_t payload_NextHop[255];
	nx_uint16_t payload_TotalCost[255];
}dvrPayload;

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
}
// 
// char* prettyOutput(dvrPayload dP) {
// 	uint8_t i;
// 	char* str = malloc(sizeof(dvrPayload));
// 	for(i = 0; i < (sizeof(dP.payload_Dest)/sizeof(dP.payload_Dest[0])); i++) {
// 		str = str + dP.payload_Dest[i] + ",";
// 	}
// 	str = str + " | ";
// 	for(i = 0; i < (sizeof(dP.payload_NextHop)/sizeof(dP.payload_NextHop[0])); i++) {
// 		str = str + dP.payload_NextHop[i] + ",";
// 	}
// 	str = str + " | ";
// 	for(i = 0; i < (sizeof(dP.payload_TotalCost)/sizeof(dP.payload_TotalCost[0])); i++) {
// 		str = str + dP.payload_TotalCost[i] + ",";
// 	}
// }

// void logDvr(pack *input) {
// 	dbg(ROUTING_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
// 	input->src, input->dest, input->seq, input->TTL, input->protocol, prettyOutput(*input->payload));
// }

enum{
	AM_PACK=6
};

#endif
