/**
 * Copyright: Copyright (c) 2010 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Nov 8, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dvm.commands.Fetch;

import tango.core.Exception;
import tango.io.device.File;
import Path = tango.io.Path;
import tango.net.http.HttpGet;
import tango.net.http.HttpConst;
import tango.text.convert.Format : format = Format;

import dvm.commands.Command;
import dvm.core._;
import dvm.util._;
import dvm.dvm._;

class Fetch : Command
{
	this (string name, string summary = "")
	{
		super(name, summary);
	}
	
	this ()
	{
		super("fetch", "Fetch a D compiler but don't install it.");
	}
	
	void execute ()
	{
		auto filename = buildFilename;
		auto url = buildUrl(filename);
		fetch(url, Path.join(".", filename));
	}
	
protected:
	
	void fetch (string source, string destination)
	{
		if (Path.exists(destination))
			return;
		
		createPath(Path.parse(destination).folder);
		writeFile(downloadFile(source), destination);
	}
	
	void[] downloadFile (string url)
	{
		auto page = new HttpGet(url);
		auto buffer = page.open;
		
		checkPageStatus(page, url);

		// load in chunks in order to display progress
		int content_length = page.getResponseHeaders.getInt(HttpHeader.ContentLength);
		const int width = 40;
		int num = width;
		string clear_line = "\x1B[1K"; // clear backwards
		string save_cursor = "\x1B[s";
		string unsave_cursor = "\x1B[u";
		
		verbose_raw(save_cursor);
		try {
			int bytes_left = content_length;
			int chunk_size = bytes_left / num;
			while ( bytes_left > 0 ) {
				buffer.load (chunk_size > bytes_left ? bytes_left : chunk_size);
				bytes_left -= chunk_size;
				verbose_raw(clear_line ~ unsave_cursor ~ save_cursor);
				int i = 0;
				verbose_raw("[");
				for ( ; i < (width - num); i++)
					verbose_raw("#");
				for ( ; i < width; i++) 
					verbose_raw(" ");
				verbose_raw("]");
				verbose_raw(" ", (content_length - bytes_left) / 1024, "/", content_length / 1024, " KB");
				num--;
			}
			
		} finally {page.close;}
		verbose(unsave_cursor);

		return buffer.slice;
	}
	
	void writeFile (void[] data, string filename)
	{
		auto file = new File(filename, File.WriteCreate);
		file.write(data);
	}
	
	string buildFilename ()
	{
		return "dmd." ~ args.first ~ ".zip";
	}
	
	string buildUrl (string filename)
	{
		return "http://ftp.digitalmars.com/" ~ filename;
	}
	
	void createPath (string path)
	{
		if (!Path.exists(path))
			Path.createPath(path);
	}
	
	void checkPageStatus (HttpGet page, string url)
	{
		if (page.getStatus == 404)
			throw new IOException(format(`The resource with URL "{}" could not be found.`, url));
		
		else if (!page.isResponseOK)
			throw new IOException(format(`An unexpected error occurred. The resource "{}" responded with the message "{}" and the status code {}.`, url, page.getResponse.getReason, page.getResponse.getStatus));
	}
}

template FetchImpl ()
{	
	void execute ()
	{
		auto filename = buildFilename;
		auto url = buildUrl(filename);
		fetch(url, join(".", filename));
	}
	
	protected void fetch (string source, string destination)
	{
		writeFile(downloadFile(source), destination);
	}
	
	private void[] downloadFile (string url)
	{
		auto page = new HttpGet(url);
		
		if (!page.isResponseOK())
			throw new IOException(format("{}", page.getResponse.getStatus));
		
		return page.read;
	}
	
	private void writeFile (void[] data, string filename)
	{
		auto file = new File(filename, File.WriteCreate);
		file.write(data);
	}
	
	private string buildFilename ()
	{
		return "dmd." ~ args.first ~ ".zip";
	}
	
	private string buildUrl (string filename)
	{
		return "http://ftp.digitalmars.com/" ~ filename;
	}
}
