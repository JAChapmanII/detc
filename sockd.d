#!/usr/bin/dmd -run
import std.stdio;
import std.socket;
import std.string;
import std.conv;
import std.array;

int main(string[] args) {
	if(args.length < 3) {
		writeln("Usage: " ~ args[0] ~ " <URL> <PAGE> [<IP>]");
		writeln("Fetch the URL given. If IP is present, attempt to use it as");
		writeln("the resolved name instead of trying to resolve URL directly");
		return 1;
	}

	string target = args[1];
	string page = args[2];
	uint ip; InternetHost ih = new InternetHost();
	if(args.length < 4) {
		if(!ih.getHostByName(target)) {
			writeln("Could not resolve host");
			return 1;
		}
		ip = ih.addrList[0];
	} else {
		if(!ih.getHostByAddr(args[3])) {
			writeln("Could not resolve host");
			return 1;
		}
		ip = ih.addrList[0];
	}

	writeln("Fetching: " ~ target ~ "/" ~ page ~ " [", ip,  "]");
	Socket mySock = 
		new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.IP);
	mySock.connect(new InternetAddress(ip, 80));

	if(!mySock.isAlive()) {
		writeln("Couldn't connect.");
		return 1;
	}

	writeln("Connected to server, sending request");
	writeln(replace(replace(center("||Request||", 80), " ", "-"), "|", " "));
	write("GET /" ~ page ~ " HTTP/1.1\n");
	write("Host: " ~ target ~ "\n");
	write("\n");
	writeln(replace(replace(center("||/Request|", 80), " ", "-"), "|", " "));
	mySock.send("GET /" ~ page ~ " HTTP/1.1\n");
	mySock.send("Host: " ~ target ~ "\n");
	mySock.send("\n");

	//mySock.shutdown(SocketShutdown.BOTH);
	//mySock.blocking(false);

	bool afterHeader;
	auto fout = File("output.file", "w");
	char[] buf = new char[(4096 << 4)];
	long gtotal, total, headerLength, targetTotal = (1 << 30), startWrite = -2;
	int responseCode = -1;
	while(mySock.isAlive()) {
		total = mySock.receive(buf); gtotal += total;
		if(!afterHeader) {
			foreach(char[] cline; splitlines(buf)) {
				string line = cast(string)(cline);
				headerLength += (line.length + 2);
				if(line.startsWith("HTTP/1.1 ")) {
					string[] responseString = split(line);
					responseCode = to!(int)(responseString[1]);
				}
				if(line.startsWith("Content-Length: ")) {
					targetTotal = to!(int)(line[16..$]);
					writeln("Content-Length: ", targetTotal);
				}
				if(!line.length) {
					afterHeader = true;
					headerLength -= 1;
					if(targetTotal != (1 << 30))
						targetTotal += headerLength;
					startWrite = headerLength;
					writeln("Header is complete");
					break;
				}
			}
		}
		if((total == Socket.ERROR) || (total < 1)) {
			break;
		}

		if(startWrite < -1)
			continue;
		if(startWrite > 0) {
			writeln(replace(replace(center("||Header||", 80), " ", "-"), "|", " "));
			writeln(buf[0..startWrite-2]);
			writeln(replace(replace(center("||/Header|", 80), " ", "-"), "|", " "));
			write("Receiving... ");
		}
		if((responseCode > 0) && (responseCode != 200)) {
			writeln("Response was not 200, aborting...");
			break;
		}
		fout.write(buf[startWrite+1..total]);
		startWrite = -1;

		write("... ");

		if(gtotal > targetTotal) {
			writeln("Fetched up to ", targetTotal);
			break;
		}
	}
	writeln("\nRecieved ", gtotal, " overall bytes");
	fout.close();

	writeln("Closing connection and exiting");
	mySock.close();
	return 0;
}

