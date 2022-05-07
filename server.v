module server

import config
import time
import net
import net.http
import page_cache
import io
import file_tree

pub const (
	config_path       = 'microsvrconfig.json'
	headers_close     = http.new_custom_header_from_map({
		'Server':                           'microsvr'
		http.CommonHeader.connection.str(): 'close'
	}) or { panic('uh oh! this should never happen...') }
	headers_plain     = http.new_header(
		key: .content_type
		value: 'text/plain'
	).join(headers_close)

	http_302          = http.new_response(
		status: .found
		text: '302 Found'
		header: headers_close
	)
	http_400          = http.new_response(
		status: .bad_request
		text: '400 Bad Request'
		header: headers_plain
	)
	http_404          = http.new_response(
		status: .not_found
		text: '404 Not Found'
		header: headers_plain
	)
	http_500          = http.new_response(
		status: .internal_server_error
		text: '500 Internal Server Error'
		header: headers_plain
	)
	// the most common mime types: this is intentional redundancy. iterating
	// over a short list is faster
	common_mime_types = [
		'.html',
		'.css',
		'.js',
		'.htm',
		'.ico',
		'.jpeg',
		'.jpg',
		'.json',
		'.mp3',
		'.mp4',
		'.png',
		'.php',
		'.svg',
		'.txt',
		'.wav',
		'.webm',
		'.webp',
		'.csv',
		'.ics',
	]
	// note that this is copy-pasted from v's vweb module:
	// https://github.com/vlang/v/vlib/vweb/vweb.v
	mime_types        = {
		'.aac':    'audio/aac'
		'.abw':    'application/x-abiword'
		'.arc':    'application/x-freearc'
		'.avi':    'video/x-msvideo'
		'.azw':    'application/vnd.amazon.ebook'
		'.bin':    'application/octet-stream'
		'.bmp':    'image/bmp'
		'.bz':     'application/x-bzip'
		'.bz2':    'application/x-bzip2'
		'.cda':    'application/x-cdf'
		'.csh':    'application/x-csh'
		'.css':    'text/css'
		'.csv':    'text/csv'
		'.doc':    'application/msword'
		'.docx':   'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
		'.eot':    'application/vnd.ms-fontobject'
		'.epub':   'application/epub+zip'
		'.gz':     'application/gzip'
		'.gif':    'image/gif'
		'.htm':    'text/html'
		'.html':   'text/html'
		'.ico':    'image/vnd.microsoft.icon'
		'.ics':    'text/calendar'
		'.jar':    'application/java-archive'
		'.jpeg':   'image/jpeg'
		'.jpg':    'image/jpeg'
		'.js':     'text/javascript'
		'.json':   'application/json'
		'.jsonld': 'application/ld+json'
		'.mid':    'audio/midi audio/x-midi'
		'.midi':   'audio/midi audio/x-midi'
		'.mjs':    'text/javascript'
		'.mp3':    'audio/mpeg'
		'.mp4':    'video/mp4'
		'.mpeg':   'video/mpeg'
		'.mpkg':   'application/vnd.apple.installer+xml'
		'.odp':    'application/vnd.oasis.opendocument.presentation'
		'.ods':    'application/vnd.oasis.opendocument.spreadsheet'
		'.odt':    'application/vnd.oasis.opendocument.text'
		'.oga':    'audio/ogg'
		'.ogv':    'video/ogg'
		'.ogx':    'application/ogg'
		'.opus':   'audio/opus'
		'.otf':    'font/otf'
		'.png':    'image/png'
		'.pdf':    'application/pdf'
		'.php':    'application/x-httpd-php'
		'.ppt':    'application/vnd.ms-powerpoint'
		'.pptx':   'application/vnd.openxmlformats-officedocument.presentationml.presentation'
		'.rar':    'application/vnd.rar'
		'.rtf':    'application/rtf'
		'.sh':     'application/x-sh'
		'.svg':    'image/svg+xml'
		'.swf':    'application/x-shockwave-flash'
		'.tar':    'application/x-tar'
		'.tif':    'image/tiff'
		'.tiff':   'image/tiff'
		'.ts':     'video/mp2t'
		'.ttf':    'font/ttf'
		'.txt':    'text/plain'
		'.vsd':    'application/vnd.visio'
		'.wav':    'audio/wav'
		'.weba':   'audio/webm'
		'.webm':   'video/webm'
		'.webp':   'image/webp'
		'.woff':   'font/woff'
		'.woff2':  'font/woff2'
		'.xhtml':  'application/xhtml+xml'
		'.xls':    'application/vnd.ms-excel'
		'.xlsx':   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
		'.xml':    'application/xml'
		'.xul':    'application/vnd.mozilla.xul+xml'
		'.zip':    'application/zip'
		'.3gp':    'video/3gpp'
		'.3g2':    'video/3gpp2'
		'.7z':     'application/x-7z-compressed'
	}
)

pub fn run() ? {
	mut cache := page_cache.Cache{}
	mut cfg := config.load_config(server.config_path)
	config.apply_config(mut cache, mut cfg)
	address := cfg.address
	port := cfg.port
	mut listener := net.listen_tcp(.ip6, '$address:$port') or {
		return error('failed to start listener!')
	}

	for true {
		mut connection := listener.accept() or {
			eprintln('failed to accept connection!')
			continue
		}

		go handle_connection(mut connection, cfg, cache)
	}
}

// send_string_data given a Response, send that response's byte array to the
// specified connection
fn send_string_data(mut connection net.TcpConn, response http.Response) {
	connection.write(response.bytes()) or {}
}

// send_response send a response to the specified connection
pub fn send_response(mut connection net.TcpConn, mimetype string, data string) {
	header := http.new_header_from_map({
		http.CommonHeader.content_type:   mimetype
		http.CommonHeader.content_length: data.len.str()
	})

	mut response := http.Response{
		header: header.join(server.headers_close)
		text: data
	}

	response.set_version(.v1_1)
	response.set_status(.found)

	send_string_data(mut connection, response)
}

// parse_request parse a http request from a tcp connection
pub fn parse_request(mut connection net.TcpConn) http.Request {
	mut reader := io.new_buffered_reader(reader: connection)

	defer {
		reader.free()
	}

	request := http.parse_request(mut reader) or { http.Request{} }

	return request
}

fn list_contains_ending(endings []string, s string) string {
	for i in 0 .. endings.len {
		ending := endings[i]
		if s.ends_with(ending) {
			return ending
		}
	}
	return ''
}

fn get_common_mime(file string) string {
	return list_contains_ending(server.common_mime_types, file)
}

fn get_mime(file string) string {
	return list_contains_ending(server.mime_types.keys(), file)
}

// get_mime_type based on a file path, determine that file's mime type
// if the file has an unrecognized format, this function will return
// a mime type of "text/plain"
fn get_mime_type(file string) string {
	// check to see if it's a common type first, because iterating over
	// a smaller list is always faster
	common_mime := get_common_mime(file)
	if common_mime.len > 0 {
		return server.mime_types[common_mime]
	}

	mime := get_mime(file)
	if mime.len > 0 {
		return server.mime_types[mime]
	}

	return ''
}

fn get_url(request http.Request) string {
	mut ret := request.url.substr(1, request.url.len)

	last_index := ret.last_index('/') or { -99 }

	if last_index == ret.len - 1 {
		ret = ret.substr(0, ret.len - 1)
	}

	return ret
}

// handle_connection handle a connection by giving it a response
fn handle_connection(mut connection net.TcpConn, cfg config.Config, cache page_cache.Cache) {
	connection.set_read_timeout(30 * time.second)
	connection.set_write_timeout(30 * time.second)

	defer {
		connection.close() or {}
	}

	request := parse_request(mut connection)
	url := get_url(request)
	mime_type := get_mime_type(url)

	if mime_type.len == 0 {
		path := url
		parent := cache.get_parent(url)
		children := cache.get_children(url)
		send_response(mut connection, 'text/html', file_tree.get_tree_page(path, parent,
			children))
		return
	}

	// if the page is valid, serve the page
	// if the page isn't valid, present a 404 response instead
	if cache.is_page_present(url) {
		send_response(mut connection, mime_type, cache.get_page(url))
	} else {
		if cfg.has_custom_404 {
			url_404 := cfg.page_not_found_page
			send_response(mut connection, 'text/html', cache.get_page(url_404))
		} else {
			connection.write(server.http_404.bytes()) or {}
		}
	}
}
