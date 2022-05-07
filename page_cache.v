// load pages BEFORE they need to be served

module page_cache

import os

pub struct Cache {
pub mut:
	file_paths    []string
	file_contents map[string]string
}

pub fn is_valid_file(path string) bool {
	if path.len < 0 {
		return false
	}

	return os.exists(path)
}

pub fn (cache Cache) get_children(path string) []string {
	original_count := path.count('/')
	mut children := []string{}

	for i in 0 .. cache.file_paths.len {
		file_path := cache.file_paths[i]
		if file_path.starts_with(path) {
			slash_count := file_path.count('/')
			if slash_count - 1 == original_count {
				children << file_path
			}
		}
	}

	return children
}

pub fn (cache Cache) get_parent(input_path string) string {
	if input_path.len < 1 {
		return ''
	}
	path := input_path.substr(0, input_path.len - 1)
	last_index := path.last_index('/') or { return '' }
	return path.substr(0, last_index - 1)
}

pub fn (mut cache Cache) shallow_cache_page(path string) {
	if !is_valid_file(path) {
		return
	}

	cache.file_paths << path
}

pub fn (mut cache Cache) cache_page(path string) {
	if !is_valid_file(path) {
		return
	}

	cache.file_paths << path
	cache.file_contents[path] = read_file(path)
}

// is_page_cached check to see if a page's contents are cached
pub fn (cache Cache) is_page_cached(path string) bool {
	return path in cache.file_contents
}

pub fn (cache Cache) is_page_present(path string) bool {
	return path in cache.file_paths
}

// get_page get the page and return its contents as a string
// if the page is cached, return the cached page
// if the page is not cached, read it and return it
pub fn (cache Cache) get_page(path string) string {
	if cache.is_page_cached(path) {
		return cache.file_contents[path]
	} else {
		return read_file(path)
	}
}

// read_file read a file from the filesystem given a path
pub fn read_file(path string) string {
	return os.read_file(path) or { error('could not read file "$path"!') }
}
