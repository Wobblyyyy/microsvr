module config

import json
import os
import page_cache

struct Config {
pub:
	folders              []string [required]
	cached_folders       []string
	cached_files         []string
	cache_page_not_found bool = true
	page_not_found_page  string
pub mut:
	has_custom_404 bool
}

pub fn load_config(path string) Config {
	config_text := page_cache.read_file(path)

	return json.decode(Config, config_text) or { panic('could not parse config! error: $err') }
}

pub fn get_all_files(path string) []string {
	children := os.ls(path) or { panic('could not list children for "$path"!') }

	mut files := []string{}

	for i in 0 .. children.len {
		child := '$path/${children[i]}'

		if os.is_dir(child) {
			child_children := get_all_files(child)

			for j in 0 .. child_children.len {
				files << child_children[j]
			}
		} else {
			files << child
		}
	}

	return files
}

pub fn apply_config(mut cache page_cache.Cache, mut cfg Config) {
	folders := cfg.folders
	cached_folders := cfg.cached_folders
	cached_files := cfg.cached_files

	page_404 := cfg.page_not_found_page
	if page_404.len > 0 {
		cfg.has_custom_404 = true
		if cfg.cache_page_not_found {
			cache.cache_page(page_404)
		} else {
			cache.shallow_cache_page(page_404)
		}
	}

	for i in 0 .. folders.len {
		folder := folders[i]
		files := get_all_files(folder)

		for j in 0 .. files.len {
			file := files[j]

			mut should_cache := false

			if folder in cached_folders {
				should_cache = true
			}

			if file in cached_files {
				should_cache = true
			}

			if should_cache {
				cache.cache_page(file)
			} else {
				cache.shallow_cache_page(file)
			}
		}
	}
}
