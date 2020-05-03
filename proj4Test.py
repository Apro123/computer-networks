from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo"); # tuna-melt

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    # s.addChannel(s.TRANSPORT_CHANNEL);
    s.addChannel(s.CHAT_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.


    s.runTime(30);
    s.appServer(1);
    s.runTime(100);
    s.appClient(3, "Hello apro 8\r\n");
    s.runTime(100);
    s.appClient(2, "Hello debul 4\r\n");
    s.runTime(100);
    s.appClient(2, "listusr\r\n");
    s.runTime(100);
    s.appClient(2, "whisper apro hi\r\n");
    s.runTime(100);
    s.appClient(3, "msg Hello World!\r\n");
    s.runTime(200);



if __name__ == '__main__':
    main()
