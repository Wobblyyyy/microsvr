// load pages BEFORE they need to be served

module page_cache

import os

pub struct Cache {
pub mut:
	file_paths    []string
	file_contents map[string]string
}

pub fn (mut cache Cache) cache_page(path string) {
	cache.file_paths << path
	cache.file_contents[path] = read_file(path)
}

// check to see if a page's contents are cached
pub fn (cache Cache) is_page_cached(path string) bool {
	return path in cache.file_contents
}

// get the page and return its contents as a string
// if the page is cached, return the cached page
// if the page is not cached, read it and return it
pub fn (cache Cache) get_page(path string) string {
	if cache.is_page_cached(path) {
		return cache.file_contents[path]
	} else {
		return read_file(path)
	}
}

// read a file from the filesystem given a path
fn read_file(path string) string {
	return os.read_file(path) or { error('could not read file "$path"!') }
}
