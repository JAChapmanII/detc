import std.stdio, std.file, std.path;
import std.string, std.conv;
import etc.c.curl, core.thread;

class RemoteFileSaver : Thread {
	public:
		this(string url, string iFileName = "") {
			super( &run );
			this.target = url;
			this.fileName = iFileName;
			if(!this.fileName.length) 
				this.fileName = basename(url);
		}

		CurlError status() {
			return this.dStatus;
		}

	private:
		string target;
		string fileName;
		CurlError dStatus;

		void run() {
			if(CURL *curl = curl_easy_init()) {
				auto f = File(this.fileName, "w");
				curl_easy_setopt(curl, CurlOption.url, toStringz(this.target));
				curl_easy_setopt(curl, CurlOption.file, f.getFP());
				this.dStatus = cast(CurlError)curl_easy_perform(curl);
				curl_easy_cleanup(curl);
			} else {
				this.dStatus = CurlError.failed_init;
			}
		}
}

int main(string[] args) {
	if(args.length == 1) {
		writeln("Usage: " ~ args[0] ~ " <URL> [<URL> [<URL> ...]]");
		writeln("Saves each URL to the basename of the URL");
		return 0;
	} args = args[1..$];
	RemoteFileSaver[] fileRFS = new RemoteFileSaver[args.length];
	foreach(i, url; args) {
		fileRFS[i] = new RemoteFileSaver(url);
		fileRFS[i].start();
	}
	writeln("Everybody started");
	foreach(i, url; args) {
		fileRFS[i].join();
		if(fileRFS[i].status() != CurlError.ok) 
			writeln("The remote file " ~ url ~ " could not be downloaded.");
		else
			writeln("file ", i, " downloaded.");
	}

	return 0;
}

