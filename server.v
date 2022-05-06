module server

import config
import time
import net
import net.http
import net.urllib
import page_cache
import io

pub const (
	config_path   = 'microsvrconfig.json'
	headers_close = http.new_custom_header_from_map({
		'Server':                           'microsvr'
		http.CommonHeader.connection.str(): 'close'
	}) or { panic('uh oh! this should never happen...') }
	headers_plain = http.new_header(
		key: .content_type
		value: 'text/plain'
	).join(headers_close)

	http_302      = http.new_response(
		status: .found
		text: '302 Found'
		header: headers_close
	)
	http_400      = http.new_response(
		status: .bad_request
		text: '400 Bad Request'
		header: headers_plain
	)
	http_404      = http.new_response(
		status: .not_found
		text: '404 Not Found'
		header: headers_plain
	)
	http_500      = http.new_response(
		status: .internal_server_error
		text: '500 Internal Server Error'
		header: headers_plain
	)
	common_mime_types = [
		'.css'
		'.csv'
		'.htm'
		'.html'
		'.ico'
		'.ics'
		'.jpeg'
		'.jpg'
		'.js'
		'.json'
		'.mp3'
		'.mp4'
		'.png'
		'.php'
		'.svg'
		'.txt'
		'.wav'
		'.webm'
		'.webp'
	]
	// note that this is copy-pasted from v's vweb module:
	// https://github.com/vlang/v/vlib/vweb/vweb.v
	mime_types    = {
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
	mut listener := net.listen_tcp(.ip6, 'localhost:8080') or {
		return error('failed to start listener!')
	}

	for true {
		mut connection := listener.accept() or {
			eprintln('failed to accept connection!')
			continue
		}

		handle_connection(mut connection, mut cfg, mut cache)
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

pub fn parse_request(mut connection net.TcpConn) http.Request {
	mut reader := io.new_buffered_reader(reader: connection)

	defer {
		reader.free()
	}

	request := http.parse_request(mut reader) or { panic('error parsing request!') }

	return request
}

fn list_contains_ending(endings []string, file string) bool {
	for i in 0 .. endings.len {
		ending := endings[i]
		if file.ends_with(ending) {
			return true
		}
	}
	return false
}

fn is_common_mime_type(file string) bool {
	return list_contains_ending(server.common_mime_types, file)
}

fn is_mime_type(file string) bool {
	return list_contains_ending(server.mime_types.keys(), file)
}

fn get_mime_type(file string) string {
	if is_common_mime_type(file) || is_mime_type(file) {
		return mime_types[file]
	}

	return 'text/plain'
}

// handle_connection handle a connection by giving it a response
fn handle_connection(mut connection net.TcpConn, mut cfg config.Config, mut cache page_cache.Cache) {
	connection.set_read_timeout(30 * time.second)
	connection.set_write_timeout(30 * time.second)

	defer {
		connection.close() or {}
	}

	request := parse_request(mut connection)
	url := request.url.substr(1, request.url.len)
	mime_type := get_mime_type(url)

	if cache.is_page_present(url) {
		send_response(mut connection, mime_type, cache.get_page(url))
	} else {
		if cfg.has_custom_404 {
			url_404 := cfg.page_not_found_page
			send_response(mut connection, mime_type, cache.get_page(url_404))
		} else {
			connection.write(server.http_404.bytes()) or {}
		}
	}
}

[manualfree]
fn serve_static(url urllib.URL) bool {
	return true
}
