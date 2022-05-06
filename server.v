module server

import config
import time
import net
import net.http
import net.urllib
import page_cache
import io

pub const (
	config_path = 'microsvrconfig.json'
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

		handle_connection(mut connection, mut cache)
	}
}

// send_string_data given a Response, send that response's byte array to the
// specified connection
fn send_string_data(mut connection net.TcpConn, response http.Response) {
	connection.write(response.bytes()) or {
		panic('there was an issue while sending a string response!')
	}
}

// send_response send a response to the specified connection
pub fn send_response(mut connection net.TcpConn, mimetype string, data string) {
	header := http.new_header_from_map({
		http.CommonHeader.content_type: mimetype
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

	request := http.parse_request(mut reader) or {
		panic('error parsing request!')
	}

	return request
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

	if cache.is_page_cached(url) {
		send_response(mut connection, 'text/html', cache.get_page(url))
	} else {
		connection.write(http_404.bytes()) or {}
	}
}

[manualfree]
fn serve_static(url urllib.URL) bool {
	return true
}
