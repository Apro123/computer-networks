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
    s.addChannel(s.TRANSPORT_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.

    s.runTime(3);
    s.testServer(2, 235);
    s.runTime(2);
    s.testClient(5, 2, 20, 235, 56);
    s.runTime(3);
    s.closeClient(5, 2, 20, 235);
    s.runTime(2);

    # s.runTime(300);
    # s.testServer(1);
    # s.runTime(60);
    #
    # s.testClient(4);
    # s.runTime(1);
    # s.runTime(1000);



if __name__ == '__main__':
    main()
